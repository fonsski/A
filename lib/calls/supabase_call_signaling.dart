import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'call_models.dart';
import 'call_signaling.dart';

/// Сигнализация звонков через таблицу `call_signals` (см. fix_018) и
/// Postgres Changes: отправка — insert строки, приём — realtime-подписка на
/// свои строки. Прочитанная строка сразу удаляется.
class SupabaseCallSignaling implements CallSignaling {
  SupabaseCallSignaling() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  final _controller = StreamController<CallSignal>.broadcast();
  RealtimeChannel? _channel;

  /// Сигналы старше этого считаем «протухшими» (звонок давно не актуален).
  static const _maxAge = Duration(seconds: 120);

  String get _uid => _client.auth.currentUser!.id;

  @override
  Stream<CallSignal> get incoming => _controller.stream;

  @override
  Future<void> start() async {
    await stop();
    final uid = _uid;
    // Хвосты прошлых сессий не должны «звонить» заново.
    try {
      await _client.from('call_signals').delete().eq('to_user', uid);
    } catch (e) {
      debugPrint('call_signals не очищены: $e');
    }
    _channel = _client
        .channel('calls-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_signals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'to_user',
            value: uid,
          ),
          callback: (payload) => _onRow(payload.newRecord),
        )
        .subscribe();
  }

  void _onRow(Map<String, dynamic> row) {
    final id = row['id'];
    unawaited(
      _client
          .from('call_signals')
          .delete()
          .eq('id', id)
          .then((_) {}, onError: (_) {}),
    );
    final createdAt = DateTime.tryParse('${row['created_at']}');
    if (createdAt != null &&
        DateTime.now().toUtc().difference(createdAt.toUtc()) > _maxAge) {
      return;
    }
    final kind = SignalKind.values.asNameMap()['${row['kind']}'];
    if (kind == null) return;
    _controller.add(
      CallSignal(
        callId: '${row['call_id']}',
        from: '${row['from_user']}',
        kind: kind,
        payload: Map<String, dynamic>.from((row['payload'] as Map?) ?? {}),
      ),
    );
  }

  @override
  Future<void> send(String to, CallSignal signal) async {
    await _client.from('call_signals').insert({
      'call_id': signal.callId,
      'from_user': _uid,
      'to_user': to,
      'kind': signal.kind.name,
      'payload': signal.payload,
    });
  }

  @override
  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
  }
}
