import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/calls/call_engine.dart';
import 'package:a_messenger/calls/call_models.dart';
import 'package:a_messenger/calls/call_service.dart';
import 'package:a_messenger/calls/call_signaling.dart';
import 'package:a_messenger/data/models.dart';

const _alice = UserSummary(
  id: 'alice',
  username: 'alice',
  displayName: 'Alice',
);
const _bob = UserSummary(id: 'bob', username: 'bob', displayName: 'Bob');

class _DeniedEngine extends MockCallEngine {
  @override
  Future<void> open({required bool video}) =>
      Future.error('NotAllowedError: Permission denied');
}

/// Пара сервисов, соединённых общей шиной сигналов.
class _Pair {
  _Pair({
    Duration ringTimeout = const Duration(seconds: 45),
    CallEngine Function()? bobEngine,
  }) {
    alice = CallService(
      signaling: MemoryCallSignaling('alice', bus),
      engineFactory: MockCallEngine.new,
      self: () => _alice,
      ringTimeout: ringTimeout,
      endedDisplay: const Duration(milliseconds: 250),
      newCallId: () => 'call-1',
    );
    bob = CallService(
      signaling: MemoryCallSignaling('bob', bus),
      engineFactory: bobEngine ?? MockCallEngine.new,
      self: () => _bob,
      ringTimeout: ringTimeout,
      endedDisplay: const Duration(milliseconds: 250),
      newCallId: () => 'call-2',
    );
  }

  final bus = MemoryCallBus();
  late final CallService alice;
  late final CallService bob;

  Future<void> attach() async {
    await alice.attach('alice');
    await bob.attach('bob');
  }

  Future<void> dispose() async {
    await alice.detach();
    await bob.detach();
    alice.dispose();
    bob.dispose();
  }

  List<SignalKind> get kinds => [for (final e in bus.log) e.signal.kind];
}

/// Даёт доставить сигналы и отработать цепочки async.
Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('CallService', () {
    late _Pair pair;

    tearDown(() => pair.dispose());

    test('звонок: приглашение → ответ → разговор → отбой', () async {
      pair = _Pair();
      await pair.attach();

      await pair.alice.startCall(_bob, withVideo: false);
      await settle();
      expect(pair.alice.phase, CallPhase.outgoing);
      expect(pair.bob.phase, CallPhase.incoming);
      expect(pair.bob.peer?.displayName, 'Alice'); // имя пришло в приглашении
      expect(pair.bob.statusText, 'Входящий звонок');

      await pair.bob.accept();
      await settle();
      expect(pair.alice.phase, CallPhase.active);
      expect(pair.bob.phase, CallPhase.active);
      expect(pair.alice.startedAt, isNotNull);
      expect(pair.kinds, [
        SignalKind.invite,
        SignalKind.accept,
        SignalKind.offer,
        SignalKind.answer,
      ]);

      await pair.alice.hangup();
      await settle();
      expect(pair.bob.phase, anyOf(CallPhase.ended, CallPhase.idle));
      expect(pair.alice.endReason, CallEndReason.localHangup);
      expect(pair.bob.endReason, CallEndReason.remoteHangup);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(pair.alice.phase, CallPhase.idle);
      expect(pair.bob.phase, CallPhase.idle);
    });

    test('видеозвонок помнит тип звонка у обоих', () async {
      pair = _Pair();
      await pair.attach();
      await pair.alice.startCall(_bob, withVideo: true);
      await settle();
      expect(pair.bob.video, isTrue);
      expect(pair.bob.statusText, 'Входящий видеозвонок');
      expect(pair.alice.camOn, isTrue);
      expect(pair.alice.speakerOn, isTrue); // видео — по умолчанию громко
    });

    test('отклонённый звонок: звонящий видит причину', () async {
      pair = _Pair();
      await pair.attach();
      await pair.alice.startCall(_bob, withVideo: false);
      await settle();

      await pair.bob.decline();
      await settle();
      expect(pair.bob.phase, CallPhase.idle); // у отклонившего — сразу
      expect(pair.alice.phase, CallPhase.ended);
      expect(pair.alice.endReason, CallEndReason.declined);
      expect(pair.alice.statusText, 'Звонок отклонён');
    });

    test('звонящий передумал: у вызываемого звонок пропадает', () async {
      pair = _Pair();
      await pair.attach();
      await pair.alice.startCall(_bob, withVideo: false);
      await settle();

      await pair.alice.hangup();
      await settle();
      expect(pair.kinds, contains(SignalKind.cancel));
      expect(pair.bob.phase, CallPhase.idle);
    });

    test('вызываемый занят: звонящий получает busy', () async {
      pair = _Pair();
      await pair.attach();
      // Боб уже сам звонит кому-то.
      await pair.bob.startCall(
        const UserSummary(id: 'carol', username: 'carol', displayName: 'Carol'),
        withVideo: false,
      );
      await pair.alice.startCall(_bob, withVideo: false);
      await settle();

      expect(pair.alice.endReason, CallEndReason.busy);
      expect(pair.alice.statusText, 'Собеседник занят');
      expect(pair.bob.phase, CallPhase.outgoing); // свой звонок не тронут
    });

    test('нет ответа: оба закрывают звонок по таймауту', () async {
      pair = _Pair(ringTimeout: const Duration(milliseconds: 150));
      await pair.attach();
      await pair.alice.startCall(_bob, withVideo: false);
      await settle();
      expect(pair.bob.phase, CallPhase.incoming);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(pair.alice.endReason, CallEndReason.noAnswer);
      expect(pair.bob.phase, CallPhase.idle); // пропущенный
    });

    test('нет доступа к микрофону: приглашение не уходит', () async {
      pair = _Pair();
      // Алисе подсовываем «запрещённый» движок через второй сервис.
      final denied = CallService(
        signaling: MemoryCallSignaling('dave', pair.bus),
        engineFactory: _DeniedEngine.new,
        self: () => _alice,
        endedDisplay: const Duration(milliseconds: 20),
      );
      await denied.attach('dave');
      await denied.startCall(_bob, withVideo: false);
      await settle();
      expect(denied.endReason, CallEndReason.deviceError);
      expect(pair.bus.log, isEmpty);
      denied.dispose();
      await pair.attach(); // чтобы tearDown отработал штатно
    });

    test('кнопки: микрофон, звук, камера только в видеозвонке', () async {
      pair = _Pair();
      await pair.attach();
      await pair.alice.startCall(_bob, withVideo: false);

      expect(pair.alice.micOn, isTrue);
      pair.alice.toggleMic();
      expect(pair.alice.micOn, isFalse);

      await pair.alice.toggleSpeaker();
      expect(pair.alice.speakerOn, isTrue);

      // В аудиозвонке камеру не включить — ничего не меняется.
      expect(pair.alice.toggleCamera(), isFalse);
      expect(pair.alice.camOn, isFalse);

      pair.alice.setMinimized(true);
      expect(pair.alice.minimized, isTrue);
    });

    test('второй входящий во время звонка не ломает первый', () async {
      pair = _Pair();
      await pair.attach();
      await pair.alice.startCall(_bob, withVideo: false);
      await settle();
      await pair.bob.accept();
      await settle();

      // Посторонний звонит Бобу — получит busy.
      final eve = CallService(
        signaling: MemoryCallSignaling('eve', pair.bus),
        engineFactory: MockCallEngine.new,
        self: () =>
            const UserSummary(id: 'eve', username: 'eve', displayName: 'Eve'),
        endedDisplay: const Duration(milliseconds: 20),
      );
      await eve.attach('eve');
      await eve.startCall(_bob, withVideo: false);
      await settle();
      expect(eve.endReason, CallEndReason.busy);
      expect(pair.bob.phase, CallPhase.active);
      await eve.detach();
      eve.dispose();
    });
  });

  test('IceCandidateData переживает JSON', () {
    const c = IceCandidateData(
      candidate: 'candidate:1 1 udp 2122 1.2.3.4 5000 typ host',
      sdpMid: '0',
      sdpMLineIndex: 0,
    );
    final back = IceCandidateData.fromJson(c.toJson());
    expect(back.candidate, c.candidate);
    expect(back.sdpMid, '0');
    expect(back.sdpMLineIndex, 0);
  });

  test('peerFromInvite достаёт имя и аватар из приглашения', () {
    final peer = peerFromInvite(
      const CallSignal(
        callId: 'c',
        from: 'u1',
        kind: SignalKind.invite,
        payload: {'name': 'Виктор', 'username': 'viktor', 'avatar': 'a.png'},
      ),
    );
    expect(peer.id, 'u1');
    expect(peer.displayName, 'Виктор');
    expect(peer.avatarUrl, 'a.png');
  });
}
