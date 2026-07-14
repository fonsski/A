import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/data/friends_repository.dart';
import 'package:a_messenger/data/mock/mock_friends_repository.dart';

void main() {
  group('MockFriendsRepository', () {
    late MockFriendsRepository repo;

    setUp(() => repo = MockFriendsRepository());

    FriendStatus? statusOf(List<FriendEntry> list, String id) =>
        list.where((e) => e.user.id == id).map((e) => e.status).firstOrNull;

    test('стартовое состояние: один друг и одна входящая заявка', () async {
      final list = await repo.watchFriends().first;
      expect(statusOf(list, 'u1'), FriendStatus.friends);
      expect(statusOf(list, 'u3'), FriendStatus.incoming);
    });

    test('принятие входящей заявки делает друзьями', () async {
      await repo.accept('u3');
      final list = await repo.watchFriends().first;
      expect(statusOf(list, 'u3'), FriendStatus.friends);
    });

    test('отклонение убирает заявку', () async {
      await repo.remove('u3');
      final list = await repo.watchFriends().first;
      expect(statusOf(list, 'u3'), isNull);
    });

    test('исходящая заявка и её отмена', () async {
      await repo.sendRequest('u5');
      var list = await repo.watchFriends().first;
      expect(statusOf(list, 'u5'), FriendStatus.outgoing);

      await repo.remove('u5');
      list = await repo.watchFriends().first;
      expect(statusOf(list, 'u5'), isNull);
    });

    test('взаимная заявка сразу делает друзьями', () async {
      await repo.sendRequest('u3'); // u3 уже прислал заявку нам
      final list = await repo.watchFriends().first;
      expect(statusOf(list, 'u3'), FriendStatus.friends);
    });

    test('удаление из друзей', () async {
      await repo.remove('u1');
      final list = await repo.watchFriends().first;
      expect(statusOf(list, 'u1'), isNull);
    });
  });
}
