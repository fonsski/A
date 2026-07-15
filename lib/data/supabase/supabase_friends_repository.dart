import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../friends_repository.dart';
import '../models.dart';

/// Друзья поверх таблицы friendships (user_a < user_b, одна строка на пару).
class SupabaseFriendsRepository implements FriendsRepository {
  SupabaseFriendsRepository() : _client = Supabase.instance.client {
    _client
        .channel('friendships')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  final SupabaseClient _client;
  final _controller = StreamController<List<FriendEntry>>.broadcast();
  List<FriendEntry>? _last;

  String get _uid => _client.auth.currentUser!.id;

  /// user_a < user_b — сравнение канонических hex-форм UUID совпадает
  /// с порядком байтов в Postgres.
  (String, String) _pair(String peer) =>
      _uid.compareTo(peer) < 0 ? (_uid, peer) : (peer, _uid);

  Future<void> _refresh() async {
    final rows = await _client.from('friendships').select('''
          user_a, user_b, status, requested_by,
          a:profiles!friendships_user_a_fkey(id, username, display_name, avatar_url),
          b:profiles!friendships_user_b_fkey(id, username, display_name, avatar_url)
        ''').or('user_a.eq.$_uid,user_b.eq.$_uid');
    _last = [
      for (final r in rows)
        () {
          final peer = ((r['user_a'] == _uid ? r['b'] : r['a']) ?? const {})
              as Map<String, dynamic>;
          final status = r['status'] == 'accepted'
              ? FriendStatus.friends
              : r['requested_by'] == _uid
                  ? FriendStatus.outgoing
                  : FriendStatus.incoming;
          return FriendEntry(
            user: UserSummary(
              id: (peer['id'] ?? '') as String,
              username: (peer['username'] ?? '') as String,
              displayName: (peer['display_name'] ??
                  peer['username'] ??
                  'Кто-то') as String,
              avatarUrl: peer['avatar_url'] as String?,
            ),
            status: status,
          );
        }(),
    ];
    _controller.add(_last!);
  }

  @override
  Set<String> get currentFriends => {
        for (final e in _last ?? const <FriendEntry>[])
          if (e.status == FriendStatus.friends) e.user.id,
      };

  @override
  Stream<List<FriendEntry>> watchFriends() async* {
    if (_last != null) yield _last!;
    unawaited(_refresh());
    yield* _controller.stream;
  }

  @override
  Future<void> sendRequest(String userId) async {
    final (a, b) = _pair(userId);
    try {
      await _client.from('friendships').insert({
        'user_a': a,
        'user_b': b,
        'requested_by': _uid,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Пара уже существует: либо взаимная заявка — принимаем, либо дубль.
        final existing = _last?.where((f) => f.user.id == userId).firstOrNull;
        if (existing?.status == FriendStatus.incoming) {
          await accept(userId);
          return;
        }
      } else {
        rethrow;
      }
    }
    await _refresh();
  }

  @override
  Future<void> accept(String userId) async {
    final (a, b) = _pair(userId);
    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('user_a', a)
        .eq('user_b', b);
    await _refresh();
  }

  @override
  Future<void> remove(String userId) async {
    final (a, b) = _pair(userId);
    await _client
        .from('friendships')
        .delete()
        .eq('user_a', a)
        .eq('user_b', b);
    await _refresh();
  }
}
