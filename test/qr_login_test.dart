import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/auth/qr_login.dart';
import 'package:a_messenger/screens/auth/login_screen.dart';
import 'package:a_messenger/screens/qr_scan_screen.dart';
import 'package:a_messenger/theme.dart';

Widget _app(Widget home) =>
    MaterialApp(theme: buildTheme(Brightness.light), home: home);

/// Спиннер «занято» крутится бесконечно, поэтому вместо pumpAndSettle —
/// несколько кадров, которых хватает на диалог и async-цепочку.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('QR payload', () {
    test('собирается и разбирается обратно', () {
      final raw = buildQrPayload('abc-123', 'deadbeef');
      expect(raw, 'a-qr:abc-123:deadbeef');
      final parsed = parseQrPayload(raw)!;
      expect(parsed.id, 'abc-123');
      expect(parsed.code, 'deadbeef');
    });

    test('чужой текст не принимается', () {
      expect(parseQrPayload('https://example.com'), isNull);
      expect(parseQrPayload('a-qr:only-id'), isNull);
      expect(parseQrPayload('a-qr::code'), isNull);
      expect(parseQrPayload('x-qr:id:code'), isNull);
      expect(parseQrPayload(''), isNull);
    });

    test('лишние пробелы вокруг кода не мешают', () {
      expect(parseQrPayload('  a-qr:i:c \n'), isNotNull);
    });
  });

  group('MockAuthRepository: QR-вход', () {
    test('опрашиваем, пока «телефон» не подтвердит — потом вход', () async {
      final repo = MockAuthRepository(qrApprovedAfterPolls: 3);
      final session = await repo.startQrLogin();
      expect(session.expired, isFalse);
      expect(parseQrPayload(session.payload), isNotNull);

      expect(await repo.pollQrLogin(session), QrPoll.pending);
      expect(await repo.pollQrLogin(session), QrPoll.pending);
      expect(repo.current, isNull);
      expect(await repo.pollQrLogin(session), QrPoll.signedIn);
      expect(repo.current?.email, 'demo@a.ru');
    });

    test('телефон: описание устройства и подтверждение', () async {
      final repo = MockAuthRepository();
      final session = await repo.startQrLogin();
      expect(await repo.describeQrLogin(session.payload), isNotEmpty);
      await repo.approveQrLogin(session.payload);
      expect(repo.qrApproved, contains(session.id));
    });

    test('мусорный код — понятная ошибка', () async {
      final repo = MockAuthRepository();
      await expectLater(
        repo.describeQrLogin('привет'),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        repo.approveQrLogin('привет'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('экран входа', () {
    setUp(() => authRepository = MockAuthRepository(qrApprovedAfterPolls: 2));

    testWidgets('«Войти по QR-коду» → код → подтверждение → вход', (
      tester,
    ) async {
      await tester.pumpWidget(_app(LoginScreen(onSignUpTap: () {})));
      expect(find.text('Войти по QR-коду'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await tester.tap(find.text('Войти по QR-коду'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Форма заменилась кодом; кнопка стала «Войти иначе».
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Войти иначе'), findsOneWidget);
      expect(find.text('Email или имя пользователя'), findsNothing);
      expect(authRepository.current, isNull);

      // Два опроса по 2 секунды — «телефон» подтверждает.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));
      expect(authRepository.current, isNotNull);

      await tester.pumpWidget(const SizedBox()); // остановить таймеры
    });

    testWidgets('«Войти иначе» возвращает форму с паролем', (tester) async {
      await tester.pumpWidget(_app(LoginScreen(onSignUpTap: () {})));
      await tester.tap(find.text('Войти по QR-коду'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Войти иначе'));
      await tester.pump();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Email или имя пользователя'), findsOneWidget);
      expect(find.text('Войти по QR-коду'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('экран сканирования (телефон)', () {
    late MockAuthRepository repo;
    late void Function(String) emit;

    setUp(() => authRepository = repo = MockAuthRepository());

    Widget screen() => _app(
      QrScanScreen(
        scannerBuilder: (onCode) {
          emit = onCode;
          return const SizedBox.expand();
        },
      ),
    );

    testWidgets('код со сканера → окно подтверждения → вход подтверждён', (
      tester,
    ) async {
      await tester.pumpWidget(screen());
      emit(buildQrPayload('qr-1', 'code-1'));
      await _flush(tester);

      expect(find.text('Войти на другом устройстве?'), findsOneWidget);
      expect(find.textContaining('Тестовое устройство'), findsOneWidget);

      await tester.tap(find.text('Подтвердить'));
      await _flush(tester);
      expect(repo.qrApproved, contains('qr-1'));
    });

    testWidgets('«Отмена» ничего не подтверждает', (tester) async {
      await tester.pumpWidget(screen());
      emit(buildQrPayload('qr-2', 'code-2'));
      await _flush(tester);
      await tester.tap(find.text('Отмена'));
      await _flush(tester);
      expect(repo.qrApproved, isEmpty);
      expect(find.byType(QrScanScreen), findsOneWidget);
    });

    testWidgets('чужой QR — подсказка, окна нет', (tester) async {
      await tester.pumpWidget(screen());
      emit('https://example.com');
      await _flush(tester);
      expect(find.text('Это не QR-код входа в «А?»'), findsOneWidget);
      expect(find.text('Войти на другом устройстве?'), findsNothing);
    });

    testWidgets('код можно вставить руками', (tester) async {
      await tester.pumpWidget(screen());
      await tester.enterText(
        find.byType(TextField),
        buildQrPayload('qr-3', 'code-3'),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _flush(tester);
      expect(find.text('Войти на другом устройстве?'), findsOneWidget);
      await tester.tap(find.text('Подтвердить'));
      await _flush(tester);
      expect(repo.qrApproved, contains('qr-3'));
    });
  });
}
