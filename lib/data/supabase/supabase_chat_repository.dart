import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chat_repository.dart';
import '../models.dart';
import 'snapshot_stream.dart';

class _MessagesState {
  final controller = StreamController<List<Message>>.broadcast();
  var rows = const <Map<String, dynamic>>[];
  final hidden = <String>{};
  var ready = false;

  /// До какого id собеседник прочитал чат (chat_members.last_read_message_id).
  var peerLastRead = 0;
  StreamSubscription<List<Map<String, dynamic>>>? sub;
  StreamSubscription<List<Map<String, dynamic>>>? membersSub;
}

/// Чаты поверх Supabase: view `chat_overview` + realtime на `messages`.
/// Требует applied supabase/schema.sql.
class SupabaseChatRepository
    with WidgetsBindingObserver
    implements ChatRepository {
  SupabaseChatRepository() : _client = Supabase.instance.client {
    WidgetsBinding.instance.addObserver(this);
    // Новые и удалённые сообщения в моих чатах обновляют список и открытые
    // ленты: realtime-подписка самой ленты (stream) на телефоне молча
    // пропускает всё, что пришло, пока приложение было в фоне.
    _client
        .channel('chats-overview')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            _refreshChats();
            _reloadMessages(payload.newRecord['chat_id'] as String?);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            _refreshChats();
            _reloadMessages(null);
          },
        )
        // Собеседник прочитал чат — в списке «А» становится «АА».
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_members',
          callback: (_) => _refreshChats(),
        )
        .subscribe();
  }

  /// Вернулись в приложение: пока оно было в фоне, сокет мог оборваться и
  /// события пропасть — перечитываем список и открытые ленты.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_client.auth.currentUser == null) return;
    unawaited(_refreshChats());
    _reloadMessages(null);
  }

  final SupabaseClient _client;
  final _chatsController = StreamController<List<ChatSummary>>.broadcast();
  List<ChatSummary>? _lastChats;

  String get _uid => _client.auth.currentUser!.id;

  Future<void> _refreshChats() async {
    final rows = await _client
        .from('chat_overview')
        .select()
        .eq('user_id', _uid)
        .order('last_at', ascending: false);
    _lastChats = [
      for (final r in rows)
        ChatSummary(
          id: r['chat_id'] as String,
          peerName: (r['peer_name'] ?? 'Чат') as String,
          lastText: switch (r['last_kind'] as String?) {
            'clear' => 'Чат очищен',
            'pin' => 'Сообщение закреплено',
            _ => switch (r['last_attachment'] as String?) {
              'image' => attachmentPreview(
                AttachmentKind.image,
                (r['last_body'] ?? '') as String,
              ),
              'video' => attachmentPreview(
                AttachmentKind.video,
                (r['last_body'] ?? '') as String,
              ),
              'file' => attachmentPreview(
                AttachmentKind.file,
                (r['last_body'] ?? '') as String,
              ),
              'voice' => attachmentPreview(AttachmentKind.voice),
              'circle' => attachmentPreview(AttachmentKind.circle),
              _ =>
                r['last_at'] != null &&
                        ((r['last_body'] ?? '') as String).isEmpty
                    ? '📎 Вложение'
                    : (r['last_body'] ?? '') as String,
            },
          },
          lastAt: r['last_at'] == null
              ? null
              : DateTime.parse(r['last_at'] as String),
          unread: (r['unread'] as num?)?.toInt() ?? 0,
          // Колонок может не быть, пока не применён fix_020 — тогда «А».
          lastMine: r['last_kind'] == 'user' && r['last_author_id'] == _uid,
          lastRead: switch ((r['last_id'], r['peer_last_read'])) {
            (final num id, final num read) => read >= id,
            _ => false,
          },
          peerAvatarUrl: r['peer_avatar'] as String?,
          peerId: r['peer_id'] as String?,
          peerUsername: r['peer_username'] as String?,
        ),
    ];
    _chatsController.add(_lastChats!);
  }

  @override
  Stream<List<ChatSummary>> watchChats() => snapshotThenUpdates(
    _chatsController.stream,
    snapshot: () => _lastChats,
    afterSubscribe: () => unawaited(_refreshChats()),
  );

  /// Состояние ленты чата: строки из realtime + мои скрытые сообщения.
  final _messageStates = <String, _MessagesState>{};

  _MessagesState _messagesStateFor(String chatId) {
    return _messageStates.putIfAbsent(chatId, () {
      final state = _MessagesState();
      unawaited(_initMessages(chatId, state));
      return state;
    });
  }

  Future<void> _initMessages(String chatId, _MessagesState state) async {
    try {
      final hiddenRows = await _client
          .from('message_hidden')
          .select('message_id')
          .eq('user_id', _uid);
      state.hidden.addAll([for (final r in hiddenRows) '${r['message_id']}']);
    } catch (_) {
      // Таблица могла быть не создана — работаем без «удалено у себя».
    }
    _listenMessages(chatId, state);
    _listenPeerRead(chatId, state);
  }

  /// Следит за «прочитано до» собеседника. Для чата 1:1 это единственная
  /// строка chat_members не моего пользователя. Нет realtime (fix_020 не
  /// применён) — остаётся стартовое значение, свои сообщения будут «А».
  void _listenPeerRead(String chatId, _MessagesState state) {
    void retry(Object? reason) {
      debugPrint('Подписка на прочтение оборвалась ($reason), переподписка');
      state.membersSub?.cancel();
      Timer(const Duration(seconds: 3), () => _listenPeerRead(chatId, state));
    }

    state.membersSub = _client
        .from('chat_members')
        .stream(primaryKey: ['chat_id', 'user_id'])
        .eq('chat_id', chatId)
        .listen(
          (rows) {
            final peer = rows.where((r) => r['user_id'] != _uid);
            final read = peer.isEmpty
                ? 0
                : (peer.first['last_read_message_id'] as num?)?.toInt() ?? 0;
            if (read == state.peerLastRead) return;
            state.peerLastRead = read;
            if (state.ready) {
              state.controller.add(_visibleMessages(chatId, state));
            }
          },
          onError: retry,
          onDone: () => retry('done'),
        );
  }

  /// Подписка на сообщения чата. Если realtime-соединение оборвалось (сеть,
  /// сон ноутбука, обновление токена), переподписываемся сами: иначе чат
  /// молча переставал бы получать новые сообщения до перезагрузки страницы.
  void _listenMessages(String chatId, _MessagesState state) {
    void retry(Object? reason) {
      debugPrint('Подписка на сообщения оборвалась ($reason), переподписка');
      state.sub?.cancel();
      Timer(const Duration(seconds: 3), () => _listenMessages(chatId, state));
    }

    state.sub = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('id', ascending: true)
        .listen(
          (rows) {
            state
              ..rows = rows
              ..ready = true;
            state.controller.add(_visibleMessages(chatId, state));
          },
          onError: retry,
          onDone: () => retry('done'),
        );
  }

  /// Перечитывает сообщения открытых лент (одного чата или всех) обычным
  /// запросом, не дожидаясь realtime.
  void _reloadMessages(String? chatId) {
    for (final entry in _messageStates.entries) {
      if (chatId != null && entry.key != chatId) continue;
      unawaited(_reloadMessagesOf(entry.key, entry.value));
    }
  }

  Future<void> _reloadMessagesOf(String chatId, _MessagesState state) async {
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('id', ascending: true);
      state
        ..rows = rows
        ..ready = true;
      state.controller.add(_visibleMessages(chatId, state));
    } catch (e) {
      debugPrint('Не удалось перечитать сообщения чата ($e)');
    }
  }

  List<Message> _visibleMessages(String chatId, _MessagesState state) => [
    for (final r in state.rows)
      if (!state.hidden.contains('${r['id']}'))
        Message(
          id: '${r['id']}',
          chatId: chatId,
          text: r['body'] as String,
          sentAt: DateTime.parse(r['created_at'] as String),
          mine: r['author_id'] == _uid,
          read:
              r['author_id'] == _uid &&
              (r['id'] as num).toInt() <= state.peerLastRead,
          kind: switch (r['kind'] as String?) {
            'clear' => MessageKind.clear,
            'pin' => MessageKind.pin,
            _ => MessageKind.user,
          },
          replyToId: r['reply_to']?.toString(),
          attachmentUrl: r['image_url'] as String?,
          attachmentKind: switch (r['attachment_type'] as String?) {
            'video' => AttachmentKind.video,
            'file' => AttachmentKind.file,
            'voice' => AttachmentKind.voice,
            'circle' => AttachmentKind.circle,
            'image' => AttachmentKind.image,
            _ => r['image_url'] != null ? AttachmentKind.image : null,
          },
          attachmentName: r['attachment_name'] as String?,
          duration: r['duration_ms'] == null
              ? null
              : Duration(milliseconds: (r['duration_ms'] as num).toInt()),
          waveform: (r['waveform'] as List?)
              ?.map((v) => (v as num).toInt())
              .toList(),
        ),
  ];

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    final state = _messagesStateFor(chatId);
    return snapshotThenUpdates(
      state.controller.stream,
      snapshot: () => state.ready ? _visibleMessages(chatId, state) : null,
      // Снимок в памяти мог устареть (приложение было в фоне) — обновляем.
      afterSubscribe: () => unawaited(_reloadMessagesOf(chatId, state)),
    );
  }

  @override
  Future<void> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
  }) async {
    await _client.from('messages').insert({
      'chat_id': chatId,
      'author_id': _uid,
      'body': text,
      if (replyToId != null) 'reply_to': int.parse(replyToId),
    });
  }

  @override
  Future<void> deleteMessageForAll(String chatId, String messageId) async {
    // RLS позволяет удалять только свои; realtime обновит ленту сам.
    await _client.from('messages').delete().eq('id', int.parse(messageId));
    await _refreshChats();
  }

  @override
  Future<void> hideMessageForMe(String chatId, String messageId) async {
    await _client.from('message_hidden').upsert({
      'user_id': _uid,
      'message_id': int.parse(messageId),
    });
    final state = _messageStates[chatId];
    if (state != null) {
      state.hidden.add(messageId);
      state.controller.add(_visibleMessages(chatId, state));
    }
  }

  @override
  Future<void> sendAttachment(
    String chatId,
    Uint8List bytes,
    String mimeType,
    String filename,
    AttachmentKind kind, {
    String caption = '',
    Duration? duration,
    List<int>? waveform,
  }) async {
    // Имя в Storage — своё (кириллица/пробелы ломают ключи),
    // человекочитаемое имя хранится в attachment_name.
    final ext = filename.contains('.') ? filename.split('.').last : 'bin';
    final path = '$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('chat-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );
    final url = _client.storage.from('chat-media').getPublicUrl(path);
    await _client.from('messages').insert({
      'chat_id': chatId,
      'author_id': _uid,
      'body': caption,
      'image_url': url,
      'attachment_type': kind.name,
      'attachment_name': filename,
      'duration_ms': ?duration?.inMilliseconds,
      'waveform': ?waveform,
    });
  }

  @override
  Future<void> markRead(String chatId) async {
    await _client.rpc<void>('mark_read', params: {'chat': chatId});
    await _refreshChats();
  }

  @override
  Stream<List<String>> watchPinned(String chatId) {
    return _client
        .from('chat_pins')
        .stream(primaryKey: ['chat_id', 'message_id'])
        .eq('chat_id', chatId)
        .order('pinned_at', ascending: false)
        .map((rows) => [for (final r in rows) '${r['message_id']}']);
  }

  @override
  Future<void> pinMessage(String chatId, String messageId) async {
    await _client.rpc<void>(
      'pin_message',
      params: {'chat': chatId, 'message': int.parse(messageId)},
    );
  }

  @override
  Future<void> unpinMessage(String chatId, String messageId) async {
    await _client.rpc<void>(
      'unpin_message',
      params: {'chat': chatId, 'message': int.parse(messageId)},
    );
  }

  @override
  Stream<Map<String, List<ReactionSummary>>> watchReactions(String chatId) {
    return _client
        .from('message_reactions')
        .stream(primaryKey: ['message_id', 'user_id', 'emoji'])
        .eq('chat_id', chatId)
        .map((rows) {
          // message id → эмодзи → (счётчик, есть ли моя).
          final byMessage = <String, Map<String, ({int count, bool mine})>>{};
          for (final r in rows) {
            final emojis = byMessage.putIfAbsent(
              '${r['message_id']}',
              () => {},
            );
            final emoji = r['emoji'] as String;
            final prev = emojis[emoji];
            emojis[emoji] = (
              count: (prev?.count ?? 0) + 1,
              mine: (prev?.mine ?? false) || r['user_id'] == _uid,
            );
          }
          return {
            for (final entry in byMessage.entries)
              entry.key: [
                for (final e in entry.value.entries)
                  ReactionSummary(
                    emoji: e.key,
                    count: e.value.count,
                    mine: e.value.mine,
                  ),
              ]..sort((a, b) => b.count.compareTo(a.count)),
          };
        });
  }

  @override
  Future<void> toggleReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    final id = int.parse(messageId);
    final existing = await _client
        .from('message_reactions')
        .select('emoji')
        .eq('message_id', id)
        .eq('user_id', _uid)
        .eq('emoji', emoji)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('message_reactions')
          .delete()
          .eq('message_id', id)
          .eq('user_id', _uid)
          .eq('emoji', emoji);
    } else {
      await _client.from('message_reactions').insert({
        'message_id': id,
        'user_id': _uid,
        'chat_id': chatId,
        'emoji': emoji,
      });
    }
  }

  @override
  Future<void> clearChat(String chatId) async {
    await _client.rpc<void>('clear_chat', params: {'chat': chatId});
    await _refreshChats();
  }

  @override
  Future<void> deleteChat(String chatId) async {
    await _client.rpc<void>('delete_chat', params: {'chat': chatId});
    await _refreshChats();
  }

  @override
  Future<List<UserSummary>> searchUsers(String query) async {
    var q = query.trim();
    if (q.startsWith('@')) q = q.substring(1);
    // PostgREST-шаблоны в пользовательском вводе не нужны.
    q = q.replaceAll('%', '').replaceAll('_', r'\_').replaceAll(',', '');
    if (q.isEmpty) return const [];
    final rows = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .not('username', 'is', null)
        .neq('id', _uid)
        .or('username.ilike.%$q%,display_name.ilike.%$q%')
        .limit(20);
    return [
      for (final r in rows)
        UserSummary(
          id: r['id'] as String,
          username: r['username'] as String,
          displayName: (r['display_name'] ?? r['username']) as String,
          avatarUrl: r['avatar_url'] as String?,
        ),
    ];
  }

  @override
  Future<String> startDm(UserSummary peer) async {
    final chatId = await _client.rpc<String>(
      'start_dm',
      params: {'peer': peer.id},
    );
    await _refreshChats();
    return chatId;
  }
}
