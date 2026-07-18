import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/models.dart';

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

    test('pinMessage/unpin: плашка и системная отметка', () async {
      await repo.pinMessage('c1', 'c1-2');
      expect(await repo.watchPinned('c1').first, 'c1-2');
      final messages = await repo.watchMessages('c1').first;
      expect(messages.last.kind, MessageKind.pin);
      expect(messages.last.systemText, 'Вы закрепили сообщение');

      await repo.unpin('c1');
      expect(await repo.watchPinned('c1').first, isNull);
    });

    test('clearChat сбрасывает закреп', () async {
      await repo.pinMessage('c1', 'c1-2');
      await repo.clearChat('c1');
      expect(await repo.watchPinned('c1').first, isNull);
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
