import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/models.dart';
import 'package:a_messenger/data/reaction_usage.dart';

void main() {
  group('extractLinks', () {
    test('вытаскивает ссылки из текста', () {
      expect(
        extractLinks('глянь https://flutter.dev и http://a.ru/x?y=1 потом'),
        ['https://flutter.dev', 'http://a.ru/x?y=1'],
      );
      expect(extractLinks('без ссылок'), isEmpty);
    });
  });

  group('форматирование дат', () {
    test('formatClock — всегда часы:минуты', () {
      expect(formatClock(DateTime(2026, 7, 18, 9, 5)), '09:05');
    });

    test('formatDayLabel: сегодня, вчера, дата', () {
      final now = DateTime.now();
      expect(formatDayLabel(now), 'Сегодня');
      expect(formatDayLabel(now.subtract(const Duration(days: 1))), 'Вчера');

      final old = now.subtract(const Duration(days: 30));
      expect(formatDayLabel(old), startsWith('${old.day} '));

      final lastYear = DateTime(now.year - 1, 3, 8);
      expect(formatDayLabel(lastYear), '8 марта ${now.year - 1}');
    });

    test('formatLastSeen: время всегда присутствует', () {
      final now = DateTime.now();
      // Берём момент в «сегодня», не попадающий на границу суток.
      final today = DateTime(now.year, now.month, now.day, 12, 35);
      expect(formatLastSeen(today), 'в 12:35');
      expect(
        formatLastSeen(today.subtract(const Duration(days: 1))),
        'вчера в 12:35',
      );
      final old = today.subtract(const Duration(days: 30));
      expect(formatLastSeen(old), endsWith(' в 12:35'));
      expect(formatLastSeen(old), isNot(startsWith('в ')));
    });

    test('sameDay сравнивает календарные дни', () {
      expect(
        sameDay(DateTime(2026, 7, 18, 23, 59), DateTime(2026, 7, 18)),
        isTrue,
      );
      expect(
        sameDay(DateTime(2026, 7, 18, 23, 59), DateTime(2026, 7, 19)),
        isFalse,
      );
    });
  });

  group('ReactionUsage', () {
    test('sorted: частые первыми, хвост в исходном порядке', () async {
      SharedPreferences.setMockInitialValues({});
      final usage = ReactionUsage(await SharedPreferences.getInstance());
      expect(usage.sorted(), kReactionEmojis);

      await usage.bump('🔥');
      await usage.bump('🔥');
      await usage.bump('😱');
      final sorted = usage.sorted();
      expect(sorted[0], '🔥');
      expect(sorted[1], '😱');
      expect(sorted.sublist(2), [
        for (final e in kReactionEmojis)
          if (e != '🔥' && e != '😱') e,
      ]);
    });

    test('счётчик переживает пересоздание (читается из prefs)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ReactionUsage(prefs).bump('💯');
      expect(ReactionUsage(prefs).sorted().first, '💯');
    });
  });

  group('MockChatRepository: поиск и старт диалога', () {
    late MockChatRepository repo;

    setUp(() => repo = MockChatRepository());

    test('ищет по нику и имени, без учёта регистра и @', () async {
      expect((await repo.searchUsers('trofim')).single.username, 'trofim');
      expect((await repo.searchUsers('@TROFIM')).single.username, 'trofim');
      expect((await repo.searchUsers('Viktor')).length, 2);
      expect(await repo.searchUsers('  '), isEmpty);
      expect(await repo.searchUsers('нет такого'), isEmpty);
    });

    test('startDm для нового собеседника создаёт пустой чат', () async {
      final panda = (await repo.searchUsers('de.panda')).single;
      final chatId = await repo.startDm(panda);
      final chats = await repo.watchChats().first;
      expect(
        chats.any((c) => c.id == chatId && c.peerName == 'Denis Panda'),
        isTrue,
      );
      final messages = await repo.watchMessages(chatId).first;
      expect(messages, isEmpty);
    });

    test('sendAttachment: фото, видео и файл с правильными превью', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      await repo.sendAttachment(
        'c3',
        bytes,
        'image/png',
        'pic.png',
        AttachmentKind.image,
      );
      var messages = await repo.watchMessages('c3').first;
      expect(messages.last.attachmentUrl, startsWith('data:image/png'));
      expect(messages.last.attachmentKind, AttachmentKind.image);
      var chats = await repo.watchChats().first;
      expect(chats.firstWhere((c) => c.id == 'c3').lastText, 'Me: 📷 Фото');

      await repo.sendAttachment(
        'c3',
        bytes,
        'video/mp4',
        'clip.mp4',
        AttachmentKind.video,
      );
      chats = await repo.watchChats().first;
      expect(chats.firstWhere((c) => c.id == 'c3').lastText, 'Me: 🎬 Видео');

      await repo.sendAttachment(
        'c3',
        bytes,
        'application/pdf',
        'doc.pdf',
        AttachmentKind.file,
      );
      messages = await repo.watchMessages('c3').first;
      expect(messages.last.attachmentName, 'doc.pdf');
      chats = await repo.watchChats().first;
      expect(chats.firstWhere((c) => c.id == 'c3').lastText, 'Me: 📎 Файл');

      // Подпись к медиа попадает в текст сообщения и в превью чата.
      await repo.sendAttachment(
        'c3',
        bytes,
        'image/png',
        'cat.png',
        AttachmentKind.image,
        caption: 'мой кот',
      );
      messages = await repo.watchMessages('c3').first;
      expect(messages.last.text, 'мой кот');
      chats = await repo.watchChats().first;
      expect(chats.firstWhere((c) => c.id == 'c3').lastText, 'Me: 📷 мой кот');
    });

    test('clearChat оставляет только системную отметку', () async {
      await repo.clearChat('c1');
      final messages = await repo.watchMessages('c1').first;
      expect(messages.single.kind, MessageKind.clear);
      expect(messages.single.systemText, 'Вы очистили чат');
      final chats = await repo.watchChats().first;
      final c1 = chats.firstWhere((c) => c.id == 'c1');
      expect(c1.lastText, 'Вы очистили чат');
      expect(c1.unread, 0);
    });

    test('sendMessage с replyToId сохраняет ссылку на исходник', () async {
      await repo.sendMessage('c3', 'отвечаю', replyToId: 'c3-1');
      final messages = await repo.watchMessages('c3').first;
      expect(messages.last.text, 'отвечаю');
      expect(messages.last.replyToId, 'c3-1');
    });

    test('deleteMessageForAll убирает сообщение и снимает его пин', () async {
      await repo.pinMessage('c1', 'c1-2');
      await repo.deleteMessageForAll('c1', 'c1-2');
      final messages = await repo.watchMessages('c1').first;
      expect(messages.any((m) => m.id == 'c1-2'), isFalse);
      expect(await repo.watchPinned('c1').first, isEmpty);
    });

    test('hideMessageForMe скрывает из выдачи и превью', () async {
      await repo.hideMessageForMe('c3', 'c3-1');
      final messages = await repo.watchMessages('c3').first;
      expect(messages.any((m) => m.id == 'c3-1'), isFalse);
      final chats = await repo.watchChats().first;
      expect(chats.firstWhere((c) => c.id == 'c3').lastText, '');
    });

    test(
      'несколько закрепов: порядок, повторный закреп, открепление',
      () async {
        await repo.pinMessage('c1', 'c1-1');
        await repo.pinMessage('c1', 'c1-2');
        expect(await repo.watchPinned('c1').first, ['c1-2', 'c1-1']);

        // Повторный закреп поднимает пин наверх.
        await repo.pinMessage('c1', 'c1-1');
        expect(await repo.watchPinned('c1').first, ['c1-1', 'c1-2']);

        final messages = await repo.watchMessages('c1').first;
        expect(messages.last.kind, MessageKind.pin);
        expect(messages.last.systemText, 'Вы закрепили сообщение');

        await repo.unpinMessage('c1', 'c1-1');
        expect(await repo.watchPinned('c1').first, ['c1-2']);
        await repo.unpinMessage('c1', 'c1-2');
        expect(await repo.watchPinned('c1').first, isEmpty);
      },
    );

    test('clearChat сбрасывает закрепы', () async {
      await repo.pinMessage('c1', 'c1-2');
      await repo.clearChat('c1');
      expect(await repo.watchPinned('c1').first, isEmpty);
    });

    test('toggleReaction: несколько реакций, повтор снимает', () async {
      // Поставить.
      await repo.toggleReaction('c3', 'c3-1', '👍');
      var reactions = await repo.watchReactions('c3').first;
      final summary = reactions['c3-1']!.single;
      expect(summary.emoji, '👍');
      expect(summary.count, 1);
      expect(summary.mine, isTrue);

      // Вторая эмодзи добавляется к первой.
      await repo.toggleReaction('c3', 'c3-1', '❤️');
      reactions = await repo.watchReactions('c3').first;
      expect(reactions['c3-1']!.map((r) => r.emoji).toSet(), {'👍', '❤️'});
      expect(reactions['c3-1']!.every((r) => r.mine), isTrue);

      // Повтор той же — снимает только её.
      await repo.toggleReaction('c3', 'c3-1', '👍');
      reactions = await repo.watchReactions('c3').first;
      expect(reactions['c3-1']!.single.emoji, '❤️');

      await repo.toggleReaction('c3', 'c3-1', '❤️');
      reactions = await repo.watchReactions('c3').first;
      expect(reactions.containsKey('c3-1'), isFalse);
    });

    test('deleteChat убирает чат из списка', () async {
      await repo.deleteChat('c3');
      final chats = await repo.watchChats().first;
      expect(chats.any((c) => c.id == 'c3'), isFalse);
    });

    test('startDm повторно возвращает существующий чат', () async {
      final trofim = (await repo.searchUsers('trofim')).single;
      // Чат с Trofim More уже есть в демо-данных (c3).
      expect(await repo.startDm(trofim), 'c3');
      expect(await repo.startDm(trofim), 'c3');
      final chats = await repo.watchChats().first;
      expect(chats.where((c) => c.peerName == 'Trofim More').length, 1);
    });
  });
}
