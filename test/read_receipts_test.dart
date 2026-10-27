import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/theme.dart';
import 'package:a_messenger/widgets/common.dart';

void main() {
  group('галочки прочтения', () {
    test('readMarkText: «А» отправлено, «АА» прочитано', () {
      expect(readMarkText(read: false), 'А');
      expect(readMarkText(read: true), 'АА');
    });

    testWidgets('ReadMark рисует нужный текст', (tester) async {
      Future<void> pump(bool read) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [AColors.light]),
          home: Scaffold(body: ReadMark(read: read)),
        ),
      );

      await pump(false);
      expect(find.text('А'), findsOneWidget);
      await pump(true);
      expect(find.text('АА'), findsOneWidget);
    });

    test(
      'мок: своё сообщение «А», пока собеседник не ответил, потом «АА»',
      () async {
        final repo = MockChatRepository(
          replyDelay: const Duration(milliseconds: 20),
        );
        final chatId = (await repo.watchChats().first).first.id;

        await repo.sendMessage(chatId, 'привет');
        final sent = (await repo.watchMessages(chatId).first).last;
        expect(sent.mine, isTrue);
        expect(sent.read, isFalse);
        final before = (await repo.watchChats().first).firstWhere(
          (c) => c.id == chatId,
        );
        expect(before.lastMine, isTrue);
        expect(before.lastRead, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 60));

        final messages = await repo.watchMessages(chatId).first;
        final mine = messages.firstWhere((m) => m.id == sent.id);
        expect(mine.read, isTrue);
        // Последним стало входящее — статус в списке уже не рисуется.
        final after = (await repo.watchChats().first).firstWhere(
          (c) => c.id == chatId,
        );
        expect(after.lastMine, isFalse);
      },
    );

    test('чужие сообщения никогда не помечаются прочитанными', () async {
      final repo = MockChatRepository(
        replyDelay: const Duration(milliseconds: 5),
      );
      final chatId = (await repo.watchChats().first).first.id;
      final messages = await repo.watchMessages(chatId).first;
      expect(messages.where((m) => !m.mine).every((m) => !m.read), isTrue);
    });
  });
}
