import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/auth/username.dart';

void main() {
  group('validateUsernameFormat', () {
    test('принимает корректные ники', () {
      for (final ok in ['abc', 'de.panda', 'a_1', 'x9.y_z', 'a' * 30]) {
        expect(validateUsernameFormat(ok), isNull, reason: ok);
      }
    });

    test('отклоняет некорректные', () {
      for (final bad in [
        '',
        'ab',
        'a' * 31,
        '.abc',
        'abc.',
        'a..b',
        'Привет',
        'a b',
        '@abc',
        '_abc',
      ]) {
        expect(validateUsernameFormat(bad), isNotNull, reason: bad);
      }
    });
  });

  group('MockAuthRepository: полный флоу регистрации', () {
    late MockAuthRepository repo;

    setUp(() {
      repo = MockAuthRepository(confirmDelay: const Duration(milliseconds: 10));
    });

    test('signUp → вход до подтверждения почты запрещён', () async {
      await repo.signUp(email: 'new@a.ru', password: 'password1');
      await expectLater(
        repo.signIn(identifier: 'new@a.ru', password: 'password1'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('после подтверждения вход работает, требуется ник', () async {
      await repo.signUp(email: 'new@a.ru', password: 'password1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await repo.signIn(identifier: 'new@a.ru', password: 'password1');
      expect(repo.current, isNotNull);
      expect(repo.current!.needsUsername, isTrue);
    });

    test(
      'claimUsername закрепляет ник, повторная регистрация ника — ошибка',
      () async {
        await repo.signUp(email: 'new@a.ru', password: 'password1');
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await repo.signIn(identifier: 'new@a.ru', password: 'password1');

        expect(await repo.isUsernameAvailable('viktor'), isTrue);
        await repo.claimUsername(username: 'viktor', displayName: 'Viktor');
        expect(repo.current!.needsUsername, isFalse);
        expect(repo.current!.profile!.username, 'viktor');
        expect(await repo.isUsernameAvailable('viktor'), isFalse);
      },
    );

    test('вход по @нику', () async {
      await repo.signIn(identifier: '@de.panda', password: 'password1');
      expect(repo.current!.email, 'demo@a.ru');
    });

    test('вход с неверным паролем — ошибка', () async {
      await expectLater(
        repo.signIn(identifier: 'demo@a.ru', password: 'wrong'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('signOut сбрасывает сессию', () async {
      await repo.signIn(identifier: 'demo@a.ru', password: 'password1');
      await repo.signOut();
      expect(repo.current, isNull);
    });

    test('updateAvatar кладёт data-URI в профиль', () async {
      await repo.signIn(identifier: 'demo@a.ru', password: 'password1');
      await repo.updateAvatar(Uint8List.fromList([1, 2, 3]), 'image/png');
      expect(repo.current!.profile!.avatarUrl, startsWith('data:image/png'));
    });

    test('updateProfile сохраняет поля, пустые строки очищают', () async {
      await repo.signIn(identifier: 'demo@a.ru', password: 'password1');
      await repo.updateProfile(
        displayName: 'Новое Имя',
        bio: 'обо мне',
        link: 'TG:@demo',
        phone: '',
      );
      final p = repo.current!.profile!;
      expect(p.displayName, 'Новое Имя');
      expect(p.bio, 'обо мне');
      expect(p.link, 'TG:@demo');
      expect(p.phone, isNull);
      expect(p.username, 'de.panda'); // ник не трогали
    });
  });
}
