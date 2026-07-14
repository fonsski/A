import 'dart:async';

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
          lastText: (r['last_body'] ?? '') as String,
          lastAt: r['last_at'] == null
              ? null
              : DateTime.parse(r['last_at'] as String),
          unread: (r['unread'] as num?)?.toInt() ?? 0,
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
        .map((rows) => [
              for (final r in rows)
                Message(
                  id: '${r['id']}',
                  chatId: chatId,
                  text: r['body'] as String,
                  sentAt: DateTime.parse(r['created_at'] as String),
                  mine: r['author_id'] == _uid,
                ),
            ]);
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
  Future<void> markRead(String chatId) async {
    await _client.rpc<void>('mark_read', params: {'chat': chatId});
    await _refreshChats();
  }
}
