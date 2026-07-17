import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../friends_repository.dart';
import '../presence_repository.dart';

/// «В сети» через Supabase Realtime Presence + last_seen_at в profiles.
///
/// Приватность по-телеграмному:
/// - online_visible_to = 'me'  → себя не транслируем и чужой онлайн не видим;
/// - 'friends' → онлайн видят только друзья (метка в payload);
/// - «был(а) в сети» отдаёт БД (last_seen_of) с теми же правилами.
class SupabasePresenceRepository implements PresenceRepository {
  SupabasePresenceRepository() : _client = Supabase.instance.client {
    _channel = _client.channel('presence:online');
    _channel
        .onPresenceSync((_) => _rebuild())
        .onPresenceJoin((_) => _rebuild())
        .onPresenceLeave((_) => _rebuild())
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(refreshVisibility());
          }
        });
    _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        unawaited(refreshVisibility());
        _startHeartbeat();
      } else if (state.event == AuthChangeEvent.signedOut) {
        _heartbeat?.cancel();
        _channel.untrack();
      }
    });
  }

  final SupabaseClient _client;
  late final RealtimeChannel _channel;
  final _controller = StreamController<Set<String>>.broadcast();

  /// user_id → кому виден ('all' | 'friends').
  var _presence = <String, String>{};
  String _myVisibility = 'all';
  Timer? _heartbeat;

  String? get _uid => _client.auth.currentUser?.id;

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _touch();
    _heartbeat = Timer.periodic(const Duration(minutes: 1), (_) => _touch());
  }

  Future<void> _touch() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client
          .from('profiles')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', uid);
    } catch (_) {
      /* сеть мигнула — следующий тик догонит */
    }
  }

  @override
  Future<void> refreshVisibility() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final row = await _client
          .from('privacy_settings')
          .select('online_visible_to')
          .eq('user_id', uid)
          .maybeSingle();
      _myVisibility = (row?['online_visible_to'] as String?) ?? 'all';
    } catch (_) {
      _myVisibility = 'all';
    }
    if (_myVisibility == 'me') {
      await _channel.untrack();
    } else {
      await _channel.track({'user_id': uid, 'vis': _myVisibility});
    }
    _emit();
  }

  void _rebuild() {
    _presence = {
      for (final state in _channel.presenceState())
        for (final p in state.presences)
          if (p.payload['user_id'] is String)
            p.payload['user_id'] as String:
                (p.payload['vis'] as String?) ?? 'all',
    };
    _emit();
  }

  Set<String> _visibleOnline() {
    // Взаимность: скрыл свой онлайн — не видишь чужой.
    if (_myVisibility == 'me') return {};
    return {
      for (final e in _presence.entries)
        if (e.key == _uid ||
            e.value == 'all' ||
            (e.value == 'friends' && _isFriend(e.key)))
          e.key,
    };
  }

  bool _isFriend(String userId) {
    try {
      return friendsRepository.currentFriends.contains(userId);
    } catch (_) {
      return false;
    }
  }

  void _emit() => _controller.add(online);

  @override
  Set<String> get online => _visibleOnline();

  @override
  Stream<Set<String>> watchOnline() async* {
    yield online;
    yield* _controller.stream;
  }

  @override
  Future<DateTime?> lastSeen(String userId) async {
    try {
      final result = await _client.rpc<dynamic>(
        'last_seen_of',
        params: {'target': userId},
      );
      if (result is String) return DateTime.parse(result);
    } catch (_) {}
    return null;
  }
}
