import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/calls/call_engine.dart';
import 'package:a_messenger/calls/call_models.dart';
import 'package:a_messenger/calls/call_service.dart';
import 'package:a_messenger/calls/call_signaling.dart';
import 'package:a_messenger/data/models.dart';
import 'package:a_messenger/screens/call_screen.dart';
import 'package:a_messenger/theme.dart';

const _alice = UserSummary(
  id: 'alice',
  username: 'alice',
  displayName: 'Alice Wonder',
);
const _bob = UserSummary(id: 'bob', username: 'bob', displayName: 'Bob');

/// Приложение-обёртка: под оверлеем обычный экран, как в `MaterialApp.builder`.
Widget _app() => MaterialApp(
  theme: buildTheme(Brightness.light),
  builder: (context, child) => CallOverlay(child: child!),
  home: const Scaffold(body: Center(child: Text('главный экран'))),
);

void main() {
  late MemoryCallBus bus;
  late CallService alice; // звонящий
  late CallService bob; // под тестом: на его экране смотрим UI

  setUp(() async {
    bus = MemoryCallBus();
    alice = CallService(
      signaling: MemoryCallSignaling('alice', bus),
      engineFactory: MockCallEngine.new,
      self: () => _alice,
      endedDisplay: const Duration(milliseconds: 500),
    );
    bob = CallService(
      signaling: MemoryCallSignaling('bob', bus),
      engineFactory: MockCallEngine.new,
      self: () => _bob,
      endedDisplay: const Duration(milliseconds: 500),
    );
    callService = bob;
  });

  // attach — внутри теста: подписки на сигналы должны жить в той же fake-async
  // зоне, где идёт pump, иначе их продолжения не выполнятся.
  Future<void> attachBoth() async {
    await alice.attach('alice');
    await bob.attach('bob');
  }

  tearDown(() async {
    await alice.detach();
    await bob.detach();
    alice.dispose();
    bob.dispose();
  });

  testWidgets('входящий: имя, «Принять/Отклонить», принять → разговор', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await attachBoth();
    expect(find.text('главный экран'), findsOneWidget);
    expect(find.text('Принять'), findsNothing);

    await alice.startCall(_bob, withVideo: false);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Alice Wonder'), findsOneWidget);
    expect(find.text('Входящий звонок'), findsOneWidget);
    expect(find.text('Принять'), findsOneWidget);
    expect(find.text('Отклонить'), findsOneWidget);
    // Свернуть входящий нельзя — кнопки «Свернуть» нет.
    expect(find.text('Свернуть в островок'), findsNothing);

    await tester.tap(find.text('Принять'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bob.phase, CallPhase.active);
    expect(find.text('Свернуть в островок'), findsOneWidget);
    expect(find.text('Завершить'), findsOneWidget);
    expect(find.textContaining('00:0'), findsOneWidget); // таймер разговора

    // Кладём трубку, чтобы не оставлять тикающий таймер звонка.
    await tester.tap(find.text('Завершить'));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('отклонить: экран исчезает, звонящий видит отказ', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await attachBoth();
    await alice.startCall(_bob, withVideo: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Входящий видеозвонок'), findsOneWidget);

    await tester.tap(find.text('Отклонить'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Отклонить'), findsNothing);
    expect(find.text('главный экран'), findsOneWidget);
    expect(alice.endReason, CallEndReason.declined);
    await tester.pump(const Duration(seconds: 1)); // закрыть таймеры
  });

  testWidgets('свернуть в островок и вернуться, затем завершить', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await attachBoth();
    await alice.startCall(_bob, withVideo: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Принять'));
    await tester.pump(const Duration(milliseconds: 200));

    // Сворачиваем: полный экран уходит, остаётся капсула с именем.
    await tester.tap(find.text('Свернуть в островок'));
    await tester.pump();
    expect(find.text('Свернуть в островок'), findsNothing);
    expect(find.text('Alice Wonder'), findsOneWidget);
    expect(find.text('главный экран'), findsOneWidget); // приложение живо

    // Тап по капсуле — снова полный экран.
    await tester.tap(find.text('Alice Wonder'));
    await tester.pump();
    expect(find.text('Свернуть в островок'), findsOneWidget);

    // Завершить: причина на экране, потом всё пропадает.
    await tester.tap(find.text('Завершить'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Звонок завершён'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Звонок завершён'), findsNothing);
    expect(find.text('главный экран'), findsOneWidget);
  });

  testWidgets(
    'кнопки: микрофон выключается, камера в аудиозвонке — подсказка',
    (tester) async {
      await tester.pumpWidget(_app());
      await attachBoth();
      await alice.startCall(_bob, withVideo: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Принять'));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Микрофон'));
      await tester.pump();
      expect(bob.micOn, isFalse);

      await tester.tap(find.text('Камера'));
      await tester.pump();
      expect(bob.camOn, isFalse);

      await tester.tap(find.text('Завершить'));
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
