import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/screens/auth/login_screen.dart';
import 'package:a_messenger/theme.dart';

/// Мок, у которого отправка письма восстановления падает как в Supabase
/// (лимит писем, запрет встроенной почты) или проходит.
class _ResetRepository extends MockAuthRepository {
  _ResetRepository({this.failure});

  final AuthFailure? failure;
  final requested = <String>[];

  @override
  Future<void> requestPasswordReset(String email) async {
    requested.add(email);
    if (failure != null) throw failure!;
  }
}

Widget _app(Widget home) =>
    MaterialApp(theme: buildTheme(Brightness.light), home: home);

Future<void> _requestReset(WidgetTester tester) async {
  await tester.pumpWidget(_app(LoginScreen(onSignUpTap: () {})));
  await tester.tap(find.text('Восстановить доступ?'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'user@example.com');
  await tester.tap(find.text('Отправить'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('письмо ушло — показываем «в пути»', (tester) async {
    final repo = _ResetRepository();
    authRepository = repo;
    await _requestReset(tester);

    expect(repo.requested, ['user@example.com']);
    expect(
      find.text('Если такая почта есть — письмо уже в пути'),
      findsOneWidget,
    );
  });

  testWidgets('ошибка отправки показывается, а не теряется', (tester) async {
    authRepository = _ResetRepository(
      failure: const AuthFailure(
        'Слишком часто — подожди минуту и попробуй снова',
      ),
    );
    await _requestReset(tester);

    expect(
      find.text('Слишком часто — подожди минуту и попробуй снова'),
      findsOneWidget,
    );
    // При ошибке обещание «письмо в пути» не показываем.
    expect(
      find.text('Если такая почта есть — письмо уже в пути'),
      findsNothing,
    );
  });

  testWidgets('не-почта отклоняется до запроса', (tester) async {
    final repo = _ResetRepository();
    authRepository = repo;
    await tester.pumpWidget(_app(LoginScreen(onSignUpTap: () {})));
    await tester.tap(find.text('Восстановить доступ?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'не-почта');
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();

    expect(repo.requested, isEmpty);
    expect(find.text('Это не похоже на почту'), findsOneWidget);
  });
}
