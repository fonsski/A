import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/auth/pin_lock.dart';
import 'package:a_messenger/data/chat_repository.dart';
import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/mock/mock_friends_repository.dart';
import 'package:a_messenger/data/models.dart';
import 'package:a_messenger/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    authRepository = MockAuthRepository();
    chatRepository = MockChatRepository();
  });

  group('PinLock', () {
    late PinLock lock;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      lock = PinLock(await SharedPreferences.getInstance());
    });

    test('без кода не заперт', () {
      expect(lock.hasPin, isFalse);
      expect(lock.locked.value, isFalse);
    });

    test('setPin → новый экземпляр заперт, верный код отпирает', () async {
      await lock.setPin('1234');
      final restarted = PinLock(await SharedPreferences.getInstance());
      expect(restarted.hasPin, isTrue);
      expect(restarted.locked.value, isTrue);
      expect(restarted.unlock('0000'), isFalse);
      expect(restarted.locked.value, isTrue);
      expect(restarted.unlock('1234'), isTrue);
      expect(restarted.locked.value, isFalse);
    });

    test('clear убирает код', () async {
      await lock.setPin('1234');
      await lock.clear();
      expect(lock.hasPin, isFalse);
      expect(PinLock(await SharedPreferences.getInstance()).locked.value,
          isFalse);
    });
  });

  group('NotificationService', () {
    ChatSummary chat(String id, int unread, [String text = 'привет']) =>
        ChatSummary(
          id: id,
          peerName: 'Peer $id',
          lastText: text,
          lastAt: DateTime.now(),
          unread: unread,
        );

    Future<(NotificationService, List<String>)> make(
        {bool enabled = true}) async {
      SharedPreferences.setMockInitialValues({kNotifyDmPref: enabled});
      final calls = <String>[];
      final service = NotificationService(
        await SharedPreferences.getInstance(),
        ensurePermission: () async => true,
        show: (title, body) => calls.add('$title|$body'),
      );
      return (service, calls);
    }

    test('первый снимок — базовая линия, без уведомлений', () async {
      final (service, calls) = await make();
      await service.onChats([chat('c1', 5)]);
      expect(calls, isEmpty);
    });

    test('рост непрочитанных в закрытом чате — уведомление', () async {
      final (service, calls) = await make();
      activeChatId = null;
      await service.onChats([chat('c1', 0)]);
      await service.onChats([chat('c1', 1, 'новое сообщение')]);
      expect(calls, ['Peer c1|новое сообщение']);
    });

    test('открытый чат и выключенный тумблер молчат', () async {
      final (service, calls) = await make();
      activeChatId = 'c1';
      await service.onChats([chat('c1', 0)]);
      await service.onChats([chat('c1', 1)]);
      expect(calls, isEmpty);
      activeChatId = null;

      final (muted, mutedCalls) = await make(enabled: false);
      await muted.onChats([chat('c2', 0)]);
      await muted.onChats([chat('c2', 3)]);
      expect(mutedCalls, isEmpty);
    });
  });

  group('MockFriendsRepository: чёрный список', () {
    late MockFriendsRepository repo;

    setUp(() => repo = MockFriendsRepository());

    test('блокировка удаляет дружбу и попадает в список', () async {
      const viktor = UserSummary(
          id: 'u1', username: 'viktor.dud', displayName: 'Viktor Dudovich');
      await repo.block(viktor);

      final friends = await repo.watchFriends().first;
      expect(friends.any((e) => e.user.id == 'u1'), isFalse);

      final blocked = await repo.watchBlocked().first;
      expect(blocked.single.username, 'viktor.dud');
      expect(repo.currentBlocked, {'u1'});
    });

    test('разблокировка очищает список', () async {
      const trofim =
          UserSummary(id: 'u3', username: 'trofim', displayName: 'Trofim');
      await repo.block(trofim);
      await repo.unblock('u3');
      expect(await repo.watchBlocked().first, isEmpty);
      expect(repo.currentBlocked, isEmpty);
    });
  });
}
