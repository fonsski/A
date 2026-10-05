import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a_messenger/data/chat_repository.dart';
import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/mock/mock_directory.dart';
import 'package:a_messenger/data/models.dart';
import 'package:a_messenger/data/presence_repository.dart';
import 'package:a_messenger/data/reaction_usage.dart';
import 'package:a_messenger/data/supabase/snapshot_stream.dart';
import 'package:a_messenger/media/voice_player.dart';
import 'package:a_messenger/screens/chat_screen.dart';
import 'package:a_messenger/theme.dart';

import 'fakes.dart';

/// Считает, сколько раз экран открывал потоки у репозитория.
class _CountingChats extends MockChatRepository {
  var messages = 0;
  var reactions = 0;
  var pinned = 0;

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    messages++;
    return super.watchMessages(chatId);
  }

  @override
  Stream<Map<String, List<ReactionSummary>>> watchReactions(String chatId) {
    reactions++;
    return super.watchReactions(chatId);
  }

  @override
  Stream<List<String>> watchPinned(String chatId) {
    pinned++;
    return super.watchPinned(chatId);
  }
}

void main() {
  group('snapshotThenUpdates', () {
    test('сначала текущее значение, потом обновления', () async {
      final live = StreamController<int>.broadcast();
      final seen = <int>[];
      final sub = snapshotThenUpdates(
        live.stream,
        snapshot: () => 1,
      ).listen(seen.add);
      live
        ..add(2)
        ..add(3);
      await pumpEventQueue();
      expect(seen, [1, 2, 3]);
      await sub.cancel();
    });

    test('событие сразу после подписки не теряется', () async {
      // Регрессия: у `yield текущее; yield* live` подписка на live оформлялась
      // лишь после первого значения, и событие в этой щели пропадало.
      final live = StreamController<int>.broadcast();
      final stream = snapshotThenUpdates(live.stream, snapshot: () => 1);
      final seen = <int>[];
      final sub = stream.listen(seen.add);
      live.add(2); // ровно в тот момент, пока слушатель получает снимок
      await pumpEventQueue();
      expect(seen, containsAllInOrder([1, 2]));
      await sub.cancel();
    });

    test('без снимка шлёт только обновления', () async {
      final live = StreamController<int>.broadcast();
      final seen = <int>[];
      final sub = snapshotThenUpdates<int>(live.stream).listen(seen.add);
      live.add(7);
      await pumpEventQueue();
      expect(seen, [7]);
      await sub.cancel();
    });

    test('afterSubscribe вызывается уже после подписки', () async {
      final live = StreamController<int>.broadcast();
      final seen = <int>[];
      // «Запрос данных» отвечает мгновенно — ответ не должен потеряться.
      final sub = snapshotThenUpdates<int>(
        live.stream,
        afterSubscribe: () => live.add(42),
      ).listen(seen.add);
      await pumpEventQueue();
      expect(seen, [42]);
      await sub.cancel();
    });

    test('отмена подписчика отписывает и от исходного потока', () async {
      var cancelled = false;
      final live = StreamController<int>.broadcast(
        onCancel: () => cancelled = true,
      );
      final sub = snapshotThenUpdates<int>(live.stream).listen((_) {});
      await sub.cancel();
      expect(cancelled, isTrue);
    });
  });

  testWidgets('экран чата не пересоздаёт подписки при наборе текста', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _CountingChats();
    chatRepository = repo;
    presenceRepository = MockPresenceRepository();
    reactionUsage = ReactionUsage(await SharedPreferences.getInstance());
    voicePlayer = VoicePlayerController(FakeAudioBackend());

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: ChatScreen(chatId: 'c3', peer: mockUsers.first),
      ),
    );
    await tester.pump();
    expect(repo.messages, 1);
    expect(repo.reactions, 1);
    expect(repo.pinned, 1);

    // Каждая буква перестраивает экран (кнопка микрофон ↔ «А?»), но потоки
    // остаются прежними.
    for (final text in ['п', 'пр', 'при', 'прив', 'приве', 'привет']) {
      await tester.enterText(find.byType(TextField).last, text);
      await tester.pump();
    }
    expect(repo.messages, 1);
    expect(repo.reactions, 1);
    expect(repo.pinned, 1);
  });
}
