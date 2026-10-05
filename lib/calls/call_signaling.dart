import 'dart:async';

import 'call_models.dart';

/// Канал служебных сообщений звонка между двумя пользователями.
abstract class CallSignaling {
  /// Сообщения, адресованные мне. Приходит только то, что отправили
  /// недавно: «протухшие» приглашения отбрасываются реализацией.
  Stream<CallSignal> get incoming;

  /// Начинает слушать входящие (после входа в аккаунт).
  Future<void> start();

  /// Отправляет сообщение пользователю [to].
  Future<void> send(String to, CallSignal signal);

  Future<void> stop();
}

/// Сигнализация в памяти: два [CallService] в одном процессе (тесты) или
/// демо-режим, где «собеседник» отвечает по сценарию.
class MemoryCallSignaling implements CallSignaling {
  MemoryCallSignaling(this.userId, this.bus);

  final String userId;
  final MemoryCallBus bus;
  final _controller = StreamController<CallSignal>.broadcast();

  @override
  Stream<CallSignal> get incoming => _controller.stream;

  @override
  Future<void> start() async => bus._join(userId, _controller);

  @override
  Future<void> send(String to, CallSignal signal) async =>
      bus._deliver(to, signal);

  @override
  Future<void> stop() async => bus._leave(userId, _controller);
}

/// Общая «шина» для [MemoryCallSignaling]: доставляет сигналы по userId.
class MemoryCallBus {
  final _inboxes = <String, StreamController<CallSignal>>{};

  /// Все отправленные сигналы по порядку — для проверок в тестах.
  final log = <({String to, CallSignal signal})>[];

  void _join(String userId, StreamController<CallSignal> c) =>
      _inboxes[userId] = c;

  void _leave(String userId, StreamController<CallSignal> c) {
    if (_inboxes[userId] == c) _inboxes.remove(userId);
  }

  void _deliver(String to, CallSignal signal) {
    log.add((to: to, signal: signal));
    // Доставка асинхронная, как у настоящей сети.
    scheduleMicrotask(() => _inboxes[to]?.add(signal));
  }
}

/// Демо-собеседник для режима без Supabase: на приглашение «берёт трубку»
/// через пару секунд и отвечает на offer, так что экран звонка можно
/// посмотреть без второго устройства.
class DemoCallSignaling implements CallSignaling {
  final _controller = StreamController<CallSignal>.broadcast();

  @override
  Stream<CallSignal> get incoming => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> send(String to, CallSignal signal) async {
    switch (signal.kind) {
      case SignalKind.invite:
        Timer(const Duration(seconds: 2), () {
          _controller.add(
            CallSignal(
              callId: signal.callId,
              from: to,
              kind: SignalKind.accept,
            ),
          );
        });
      case SignalKind.offer:
        Timer(const Duration(milliseconds: 600), () {
          _controller.add(
            CallSignal(
              callId: signal.callId,
              from: to,
              kind: SignalKind.answer,
              payload: const {'sdp': 'demo-answer'},
            ),
          );
        });
      default:
        break;
    }
  }
}
