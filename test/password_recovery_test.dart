import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:a_messenger/auth/auth_gate.dart';
import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/auth/supabase_auth_repository.dart';
import 'package:a_messenger/config.dart';
import 'package:a_messenger/screens/auth/auth_flow.dart';
import 'package:a_messenger/screens/auth/new_password_screen.dart';
import 'package:a_messenger/theme.dart';

Widget _app(Widget home) =>
    MaterialApp(theme: buildTheme(Brightness.light), home: home);

/// Спиннер «занято» крутится бесконечно, поэтому вместо pumpAndSettle —
/// несколько кадров.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('MockAuthRepository: восстановление', () {
    test('письмо открывает ссылку: recovering → новый пароль → вход', () async {
      final repo = MockAuthRepository(confirmDelay: Duration.zero);
      expect(repo.recovering.value, isFalse);

      await repo.requestPasswordReset('demo@a.ru');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.recovering.value, isTrue);

      await repo.completeRecovery('newpassword1');
      expect(repo.recovering.value, isFalse);
      expect(repo.current?.email, 'demo@a.ru');

      await repo.signOut();
      await expectLater(
        repo.signIn(identifier: 'demo@a.ru', password: 'password1'),
        throwsA(isA<AuthFailure>()),
      );
      await repo.signIn(identifier: 'demo@a.ru', password: 'newpassword1');
      expect(repo.current?.email, 'demo@a.ru');
    });

    test('неизвестная почта не выдаёт себя и ссылки не открывает', () async {
      final repo = MockAuthRepository(confirmDelay: Duration.zero);
      await repo.requestPasswordReset('nobody@a.ru');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.recovering.value, isFalse);
    });

    test('без открытой ссылки новый пароль не задать', () async {
      final repo = MockAuthRepository();
      await expectLater(
        repo.completeRecovery('newpassword1'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('тот же пароль отклоняется', () async {
      final repo = MockAuthRepository()..openRecoveryLink('demo@a.ru');
      await expectLater(
        repo.completeRecovery('password1'),
        throwsA(isA<AuthFailure>()),
      );
      expect(repo.recovering.value, isTrue);
    });

    test('отмена закрывает сессию и режим восстановления', () async {
      final repo = MockAuthRepository()..openRecoveryLink('demo@a.ru');
      await repo.cancelRecovery();
      expect(repo.recovering.value, isFalse);
      expect(repo.current, isNull);
    });
  });

  group('экран нового пароля', () {
    testWidgets('несовпадающие и слабые пароли не уходят на сервер', (
      tester,
    ) async {
      final repo = MockAuthRepository()..openRecoveryLink('demo@a.ru');
      authRepository = repo;
      await tester.pumpWidget(_app(const NewPasswordScreen()));

      await tester.enterText(find.byType(TextField).first, 'newpassword1');
      await tester.enterText(find.byType(TextField).last, 'другой');
      await tester.tap(find.text('Сохранить пароль'));
      await _flush(tester);

      expect(find.text('Пароли не совпадают'), findsOneWidget);
      expect(repo.recovering.value, isTrue);
    });

    testWidgets('сохраняет новый пароль и выходит из режима восстановления', (
      tester,
    ) async {
      final repo = MockAuthRepository()..openRecoveryLink('demo@a.ru');
      authRepository = repo;
      await tester.pumpWidget(_app(const NewPasswordScreen()));

      await tester.enterText(find.byType(TextField).first, 'newpassword1');
      await tester.enterText(find.byType(TextField).last, 'newpassword1');
      await tester.tap(find.text('Сохранить пароль'));
      await _flush(tester);

      expect(repo.recovering.value, isFalse);
      expect(repo.current?.email, 'demo@a.ru');
      expect(find.text('Пароль изменён'), findsOneWidget);
    });

    testWidgets('ошибка сервера показывается', (tester) async {
      final repo = MockAuthRepository()..openRecoveryLink('demo@a.ru');
      authRepository = repo;
      await tester.pumpWidget(_app(const NewPasswordScreen()));

      // Совпадает с текущим паролем — мок ответит ошибкой.
      await tester.enterText(find.byType(TextField).first, 'password1');
      await tester.enterText(find.byType(TextField).last, 'password1');
      await tester.tap(find.text('Сохранить пароль'));
      await _flush(tester);

      expect(find.text('Новый пароль совпадает со старым'), findsOneWidget);
      expect(repo.recovering.value, isTrue);
    });
  });

  group('AuthGate', () {
    testWidgets('при recovering показывает экран нового пароля, по отмене — '
        'вход', (tester) async {
      final repo = MockAuthRepository();
      authRepository = repo;
      await tester.pumpWidget(_app(const AuthGate()));
      expect(find.byType(AuthFlow), findsOneWidget);
      expect(find.byType(NewPasswordScreen), findsNothing);

      repo.openRecoveryLink('demo@a.ru');
      await tester.pump();
      expect(find.byType(NewPasswordScreen), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await _flush(tester);
      expect(find.byType(NewPasswordScreen), findsNothing);
      expect(find.byType(AuthFlow), findsOneWidget);
    });
  });

  group('битая ссылка из письма', () {
    testWidgets('AuthGate показывает сообщение об ошибке', (tester) async {
      final repo = MockAuthRepository();
      authRepository = repo;
      await tester.pumpWidget(_app(const AuthGate()));

      repo.failLink('Ссылка устарела или уже использована');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Ссылка устарела или уже использована'), findsOneWidget);
    });

    test('linkErrorText: тексты для разных ошибок Supabase', () {
      // Ссылка устарела: код ошибки приходит в statusCode.
      expect(
        linkErrorText(
          const sb.AuthException(
            'Email link is invalid or has expired',
            statusCode: 'otp_expired',
            code: 'access_denied',
          ),
        ),
        contains('устарела'),
      );
      expect(
        linkErrorText(
          const sb.AuthException(
            'Code verifier could not be found in local storage.',
          ),
        ),
        contains('в том же приложении'),
      );
      expect(linkErrorText(StateError('x')), contains('Не удалось открыть'));
    });
  });

  group('AppConfig.passwordResetRedirect', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('мобильные платформы и macOS возвращаются в приложение по схеме', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          AppConfig.passwordResetRedirect,
          '${AppConfig.urlScheme}://reset-password',
          reason: '$platform',
        );
      }
    });

    test('на Windows и Linux обработки ссылок нет — redirect не задаётся', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(AppConfig.passwordResetRedirect, isNull, reason: '$platform');
      }
    });
  });
}
