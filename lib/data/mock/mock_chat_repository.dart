import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../chat_repository.dart';
import '../models.dart';
import 'mock_directory.dart';

class _MockChat {
  _MockChat({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.messages,
    this.unread = 0,
  });

  final String id;
  final String peerId;
  final String peerName;
  final List<Message> messages;
  int unread;
  final pinnedIds = <String>[]; // новые закрепы первыми
  final hidden = <String>{}; // «удалено у себя»
  // message id → (кто → его эмодзи); «я» в моке — ключ 'me'.
  final reactions = <String, Map<String, Set<String>>>{};

  Map<String, List<ReactionSummary>> get reactionSummaries => {
    for (final entry in reactions.entries)
      if (entry.value.values.any((set) => set.isNotEmpty))
        entry.key: () {
          final all = entry.value.values.expand((set) => set);
          final summaries = [
            for (final emoji in all.toSet())
              ReactionSummary(
                emoji: emoji,
                count: all.where((e) => e == emoji).length,
                mine: entry.value['me']?.contains(emoji) ?? false,
              ),
          ]..sort((a, b) => b.count.compareTo(a.count));
          return summaries;
        }(),
  };

  List<Message> get visibleMessages => [
    for (final m in messages)
      if (!hidden.contains(m.id)) m,
  ];

  ChatSummary get summary => ChatSummary(
    id: id,
    peerId: peerId,
    peerUsername: mockUsers
        .where((u) => u.id == peerId)
        .map((u) => u.username)
        .firstOrNull,
    peerName: peerName,
    lastText: switch (visibleMessages.lastOrNull) {
      null => '',
      final m when m.kind != MessageKind.user => m.systemText,
      final m =>
        (m.mine ? 'Me: ' : '') +
            (m.attachmentKind != null
                ? attachmentPreview(m.attachmentKind!, m.text)
                : m.text),
    },
    lastAt: visibleMessages.lastOrNull?.sentAt,
    unread: unread,
  );
}

/// Чаты в памяти. Собеседник «отвечает» через секунду — удобно смотреть
/// realtime-поведение UI без бэкенда.
class MockChatRepository implements ChatRepository {
  MockChatRepository({this.replyDelay = const Duration(seconds: 1)}) {
    final now = DateTime.now();
    Message msg(String chatId, int n, String text, bool mine) => Message(
      id: '$chatId-$n',
      chatId: chatId,
      text: text,
      sentAt: now.subtract(Duration(minutes: 90 - n * 7)),
      mine: mine,
    );
    _chats.addAll([
      _MockChat(
        id: 'c1',
        peerId: 'u1',
        peerName: 'Viktor Dudovich',
        unread: 2,
        messages: [
          msg(
            'c1',
            1,
            'hi brother, borrow a couple thousand at the casino',
            false,
          ),
          msg('c1', 2, 'Whatsup brother', true),
          Message(
            id: 'c1-3',
            chatId: 'c1',
            text: '',
            sentAt: now.subtract(const Duration(minutes: 70)),
            mine: false,
            attachmentUrl: 'asset:assets/images/media.png',
            attachmentKind: AttachmentKind.image,
          ),
          Message(
            id: 'c1-4',
            chatId: 'c1',
            text: 'глянь доку https://flutter.dev и ещё https://supabase.com',
            sentAt: now.subtract(const Duration(minutes: 65)),
            mine: true,
          ),
          Message(
            id: 'c1-5',
            chatId: 'c1',
            text: '',
            sentAt: now.subtract(const Duration(minutes: 62)),
            mine: false,
            attachmentUrl: 'asset:assets/images/media.png',
            attachmentKind: AttachmentKind.video,
            attachmentName: 'niva_offroad.mp4',
          ),
          Message(
            id: 'c1-6',
            chatId: 'c1',
            text: '',
            sentAt: now.subtract(const Duration(minutes: 61)),
            mine: true,
            attachmentUrl: 'asset:assets/images/media.png',
            attachmentKind: AttachmentKind.file,
            attachmentName: 'смета_на_шноркель.pdf',
          ),
        ],
      ),
      _MockChat(
        id: 'c2',
        peerId: 'u2',
        peerName: 'Viktor Vozdux',
        unread: 1,
        messages: [msg('c2', 1, 'Глянь что на стенку кинул', false)],
      ),
      _MockChat(
        id: 'c3',
        peerId: 'u3',
        peerName: 'Trofim More',
        messages: [msg('c3', 1, 'договорились', true)],
      ),
    ]);
  }

  static const _directory = mockUsers;

  final Duration replyDelay;

  final _chats = <_MockChat>[];
  final _chatsController = StreamController<List<ChatSummary>>.broadcast();
  final _messageControllers = <String, StreamController<List<Message>>>{};
  var _nextId = 100;

  List<ChatSummary> get _summaries {
    final list = _chats.map((c) => c.summary).toList()
      ..sort((a, b) {
        final at = a.lastAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.lastAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
    return list;
  }

  _MockChat _chat(String id) => _chats.firstWhere((c) => c.id == id);

  StreamController<List<Message>> _controllerFor(String chatId) =>
      _messageControllers.putIfAbsent(
        chatId,
        () => StreamController<List<Message>>.broadcast(),
      );

  void _notify(String chatId) {
    _controllerFor(chatId).add(_chat(chatId).visibleMessages);
    _chatsController.add(_summaries);
  }

  @override
  Stream<List<ChatSummary>> watchChats() async* {
    yield _summaries;
    yield* _chatsController.stream;
  }

  @override
  Stream<List<Message>> watchMessages(String chatId) async* {
    yield _chat(chatId).visibleMessages;
    yield* _controllerFor(chatId).stream;
  }

  @override
  Future<void> sendMessage(
    String chatId,
    String text, {
    String? replyToId,
  }) async {
    final chat = _chat(chatId);
    chat.messages.add(
      Message(
        id: 'm${_nextId++}',
        chatId: chatId,
        text: text,
        sentAt: DateTime.now(),
        mine: true,
        replyToId: replyToId,
      ),
    );
    _notify(chatId);

    // Демо-ответ собеседника.
    Timer(replyDelay, () {
      chat.messages.add(
        Message(
          id: 'm${_nextId++}',
          chatId: chatId,
          text: 'А?',
          sentAt: DateTime.now(),
          mine: false,
        ),
      );
      _notify(chatId);
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
    _chat(chatId).messages.add(
      Message(
        id: 'm${_nextId++}',
        chatId: chatId,
        text: caption,
        sentAt: DateTime.now(),
        mine: true,
        attachmentUrl: 'data:$mimeType;base64,${base64Encode(bytes)}',
        attachmentKind: kind,
        attachmentName: filename,
      ),
    );
    _notify(chatId);
  }

  @override
  Future<void> markRead(String chatId) async {
    _chat(chatId).unread = 0;
    _chatsController.add(_summaries);
  }

  @override
  Future<void> deleteMessageForAll(String chatId, String messageId) async {
    final chat = _chat(chatId);
    chat.messages.removeWhere((m) => m.id == messageId);
    if (chat.pinnedIds.remove(messageId)) {
      _pinnedControllerFor(chatId).add(List.unmodifiable(chat.pinnedIds));
    }
    _notify(chatId);
  }

  @override
  Future<void> hideMessageForMe(String chatId, String messageId) async {
    _chat(chatId).hidden.add(messageId);
    _notify(chatId);
  }

  final _pinnedControllers = <String, StreamController<List<String>>>{};

  StreamController<List<String>> _pinnedControllerFor(String chatId) =>
      _pinnedControllers.putIfAbsent(
        chatId,
        () => StreamController<List<String>>.broadcast(),
      );

  @override
  Stream<List<String>> watchPinned(String chatId) async* {
    yield List.unmodifiable(_chat(chatId).pinnedIds);
    yield* _pinnedControllerFor(chatId).stream;
  }

  @override
  Future<void> pinMessage(String chatId, String messageId) async {
    final chat = _chat(chatId);
    // Повторный закреп поднимает пин наверх.
    chat.pinnedIds
      ..remove(messageId)
      ..insert(0, messageId);
    chat.messages.add(
      Message(
        id: 'm${_nextId++}',
        chatId: chatId,
        text: '',
        sentAt: DateTime.now(),
        mine: true,
        kind: MessageKind.pin,
      ),
    );
    _pinnedControllerFor(chatId).add(List.unmodifiable(chat.pinnedIds));
    _notify(chatId);
  }

  @override
  Future<void> unpinMessage(String chatId, String messageId) async {
    final chat = _chat(chatId);
    chat.pinnedIds.remove(messageId);
    _pinnedControllerFor(chatId).add(List.unmodifiable(chat.pinnedIds));
  }

  final _reactionControllers =
      <String, StreamController<Map<String, List<ReactionSummary>>>>{};

  StreamController<Map<String, List<ReactionSummary>>> _reactionControllerFor(
    String chatId,
  ) => _reactionControllers.putIfAbsent(
    chatId,
    () => StreamController<Map<String, List<ReactionSummary>>>.broadcast(),
  );

  @override
  Stream<Map<String, List<ReactionSummary>>> watchReactions(
    String chatId,
  ) async* {
    yield _chat(chatId).reactionSummaries;
    yield* _reactionControllerFor(chatId).stream;
  }

  @override
  Future<void> toggleReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    final chat = _chat(chatId);
    final mine = chat.reactions
        .putIfAbsent(messageId, () => {})
        .putIfAbsent('me', () => {});
    if (!mine.remove(emoji)) mine.add(emoji); // повтор — снимает
    _reactionControllerFor(chatId).add(chat.reactionSummaries);
  }

  @override
  Future<void> clearChat(String chatId) async {
    final chat = _chat(chatId);
    chat.messages
      ..clear()
      ..add(
        Message(
          id: 'm${_nextId++}',
          chatId: chatId,
          text: '',
          sentAt: DateTime.now(),
          mine: true,
          kind: MessageKind.clear,
        ),
      );
    chat.unread = 0;
    chat.pinnedIds.clear();
    _pinnedControllerFor(chatId).add(const []);
    _notify(chatId);
  }

  @override
  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((c) => c.id == chatId);
    _messageControllers.remove(chatId)?.close();
    _chatsController.add(_summaries);
  }

  @override
  Future<List<UserSummary>> searchUsers(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    var q = query.trim().toLowerCase();
    if (q.startsWith('@')) q = q.substring(1);
    if (q.isEmpty) return const [];
    return _directory
        .where(
          (u) =>
              u.username.toLowerCase().contains(q) ||
              u.displayName.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Future<String> startDm(UserSummary peer) async {
    for (final chat in _chats) {
      if (chat.peerId == peer.id) return chat.id;
    }
    final chat = _MockChat(
      id: 'c${_nextId++}',
      peerId: peer.id,
      peerName: peer.displayName,
      messages: [],
    );
    _chats.add(chat);
    _chatsController.add(_summaries);
    return chat.id;
  }
}
