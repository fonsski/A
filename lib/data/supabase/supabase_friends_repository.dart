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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'blacklist',
          callback: (_) => _refreshBlocked(),
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

  final _blockedController =
      StreamController<List<UserSummary>>.broadcast();
  List<UserSummary>? _blocked;

  Future<void> _refreshBlocked() async {
    final rows = await _client.from('blacklist').select('''
          blocked_id,
          blocked:profiles!blacklist_blocked_id_fkey(id, username, display_name, avatar_url)
        ''').eq('owner_id', _uid);
    _blocked = [
      for (final r in rows)
        () {
          final p = (r['blocked'] ?? const {}) as Map<String, dynamic>;
          return UserSummary(
            id: r['blocked_id'] as String,
            username: (p['username'] ?? '') as String,
            displayName:
                (p['display_name'] ?? p['username'] ?? 'Кто-то') as String,
            avatarUrl: p['avatar_url'] as String?,
          );
        }(),
    ];
    _blockedController.add(_blocked!);
  }

  @override
  Set<String> get currentBlocked =>
      {for (final u in _blocked ?? const <UserSummary>[]) u.id};

  @override
  Stream<List<UserSummary>> watchBlocked() async* {
    if (_blocked != null) yield _blocked!;
    unawaited(_refreshBlocked());
    yield* _blockedController.stream;
  }

  @override
  Future<void> block(UserSummary user) async {
    // Дружба/заявки не переживают блокировку.
    await remove(user.id);
    await _client.from('blacklist').upsert({
      'owner_id': _uid,
      'blocked_id': user.id,
    });
    await _refreshBlocked();
  }

  @override
  Future<void> unblock(String userId) async {
    await _client
        .from('blacklist')
        .delete()
        .eq('owner_id', _uid)
        .eq('blocked_id', userId);
    await _refreshBlocked();
  }
}
