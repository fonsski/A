import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/data/mock/mock_chat_repository.dart';

void main() {
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
      expect(chats.any((c) => c.id == chatId && c.peerName == 'Denis Panda'),
          isTrue);
      final messages = await repo.watchMessages(chatId).first;
      expect(messages, isEmpty);
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
