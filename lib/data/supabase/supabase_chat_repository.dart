import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../chat_repository.dart';
import '../models.dart';

/// Чаты поверх Supabase: view `chat_overview` + realtime на `messages`.
/// Требует applied supabase/schema.sql.
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository() : _client = Supabase.instance.client {
    // Любое новое сообщение в моих чатах (RLS фильтрует) обновляет список.
    _client
        .channel('chats-overview')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => _refreshChats(),
        )
        .subscribe();
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
          lastText: switch (r['last_attachment'] as String?) {
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
            _ =>
              r['last_at'] != null && ((r['last_body'] ?? '') as String).isEmpty
                  ? '📎 Вложение'
                  : (r['last_body'] ?? '') as String,
          },
          lastAt: r['last_at'] == null
              ? null
              : DateTime.parse(r['last_at'] as String),
          unread: (r['unread'] as num?)?.toInt() ?? 0,
          peerAvatarUrl: r['peer_avatar'] as String?,
          peerId: r['peer_id'] as String?,
          peerUsername: r['peer_username'] as String?,
        ),
    ];
    _chatsController.add(_lastChats!);
  }

  @override
  Stream<List<ChatSummary>> watchChats() async* {
    if (_lastChats != null) yield _lastChats!;
    unawaited(_refreshChats());
    yield* _chatsController.stream;
  }

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('id', ascending: true)
        .map(
          (rows) => [
            for (final r in rows)
              Message(
                id: '${r['id']}',
                chatId: chatId,
                text: r['body'] as String,
                sentAt: DateTime.parse(r['created_at'] as String),
                mine: r['author_id'] == _uid,
                attachmentUrl: r['image_url'] as String?,
                attachmentKind: switch (r['attachment_type'] as String?) {
                  'video' => AttachmentKind.video,
                  'file' => AttachmentKind.file,
                  'image' => AttachmentKind.image,
                  _ => r['image_url'] != null ? AttachmentKind.image : null,
                },
                attachmentName: r['attachment_name'] as String?,
              ),
          ],
        );
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    await _client.from('messages').insert({
      'chat_id': chatId,
      'author_id': _uid,
      'body': text,
    });
  }

  @override
  Future<void> sendAttachment(
    String chatId,
    Uint8List bytes,
    String mimeType,
    String filename,
    AttachmentKind kind, {
    String caption = '',
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
    });
  }

  @override
  Future<void> markRead(String chatId) async {
    await _client.rpc<void>('mark_read', params: {'chat': chatId});
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
