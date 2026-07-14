import 'dart:async';

import '../chat_repository.dart';
import '../models.dart';

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

  ChatSummary get summary => ChatSummary(
        id: id,
        peerName: peerName,
        lastText: messages.isEmpty
            ? ''
            : (messages.last.mine ? 'Me: ' : '') + messages.last.text,
        lastAt: messages.isEmpty ? null : messages.last.sentAt,
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
          msg('c1', 1, 'hi brother, borrow a couple thousand at the casino',
              false),
          msg('c1', 2, 'Whatsup brother', true),
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

  static const _directory = [
    UserSummary(id: 'u1', username: 'viktor.dud', displayName: 'Viktor Dudovich'),
    UserSummary(id: 'u2', username: 'vozdux', displayName: 'Viktor Vozdux'),
    UserSummary(id: 'u3', username: 'trofim', displayName: 'Trofim More'),
    UserSummary(id: 'u4', username: 'de.panda', displayName: 'Denis Panda'),
    UserSummary(id: 'u5', username: 'kirpich', displayName: 'Sasha Kirpich'),
  ];

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
          chatId, () => StreamController<List<Message>>.broadcast());

  void _notify(String chatId) {
    _controllerFor(chatId).add(List.unmodifiable(_chat(chatId).messages));
    _chatsController.add(_summaries);
  }

  @override
  Stream<List<ChatSummary>> watchChats() async* {
    yield _summaries;
    yield* _chatsController.stream;
  }

  @override
  Stream<List<Message>> watchMessages(String chatId) async* {
    yield List.unmodifiable(_chat(chatId).messages);
    yield* _controllerFor(chatId).stream;
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    final chat = _chat(chatId);
    chat.messages.add(Message(
      id: 'm${_nextId++}',
      chatId: chatId,
      text: text,
      sentAt: DateTime.now(),
      mine: true,
    ));
    _notify(chatId);

    // Демо-ответ собеседника.
    Timer(replyDelay, () {
      chat.messages.add(Message(
        id: 'm${_nextId++}',
        chatId: chatId,
        text: 'А?',
        sentAt: DateTime.now(),
        mine: false,
      ));
      _notify(chatId);
    });
  }

  @override
  Future<void> markRead(String chatId) async {
    _chat(chatId).unread = 0;
    _chatsController.add(_summaries);
  }

  @override
  Future<List<UserSummary>> searchUsers(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    var q = query.trim().toLowerCase();
    if (q.startsWith('@')) q = q.substring(1);
    if (q.isEmpty) return const [];
    return _directory
        .where((u) =>
            u.username.toLowerCase().contains(q) ||
            u.displayName.toLowerCase().contains(q))
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
