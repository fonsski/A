import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/data/chat_repository.dart';
import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/mock/mock_wall_repository.dart';
import 'package:a_messenger/data/privacy_repository.dart';
import 'package:a_messenger/data/wall_repository.dart';
import 'package:a_messenger/main.dart';
import 'package:a_messenger/screens/auth/confirm_email_screen.dart';
import 'package:a_messenger/screens/auth/login_screen.dart';
import 'package:a_messenger/screens/auth/pick_username_screen.dart';
import 'package:a_messenger/screens/auth/signup_screen.dart';
import 'package:a_messenger/screens/home_shell.dart';

void main() {
  setUpAll(() {
    authRepository =
        MockAuthRepository(confirmDelay: const Duration(seconds: 1));
    chatRepository = MockChatRepository();
    wallRepository = MockWallRepository();
    privacyRepository = MockPrivacyRepository();
  });

  testWidgets('splash → экран входа (сессии нет)', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Войти!'), findsOneWidget);
  });

  testWidgets('полный флоу: регистрация → почта → вход → ник → приложение',
      (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Вход → Вступить
    await tester.tap(find.text('Вступить'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    // Регистрация
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@a.ru');
    await tester.enterText(fields.at(1), 'password1');
    await tester.enterText(fields.at(2), 'password1');
    await tester.tap(find.text('Зарегистрироваться'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmEmailScreen), findsOneWidget);
    expect(find.textContaining('test@a.ru'), findsOneWidget);

    // «Подтверждаем» почту (мок делает это через 1 сек) и идём на вход
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Я подтвердил — войти'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Вход
    await tester.enterText(find.byType(TextField).at(0), 'test@a.ru');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.tap(find.text('Войти!'));
    await tester.pumpAndSettle();
    expect(find.byType(PickUsernameScreen), findsOneWidget);

    // Выбор ника
    await tester.enterText(find.byType(TextField).at(0), 'test.user');
    await tester.enterText(find.byType(TextField).at(1), 'Test User');
    await tester.pump(const Duration(milliseconds: 600)); // debounce проверки
    await tester.tap(find.text('Погнали!'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);

    // Повторный вход по нику после выхода
    await authRepository.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '@test.user');
    await tester.enterText(find.byType(TextField).at(1), 'password1');
    await tester.tap(find.text('Войти!'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('чат: отправка сообщения и автоответ', (tester) async {
    // Сессия сохранилась с прошлого теста — сразу HomeShell.
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HomeShell), findsOneWidget);

    await tester.tap(find.text('Viktor Dudovich'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'привет, это тест');
    await tester.tap(find.text('А?'));
    await tester.pump();
    expect(find.text('привет, это тест'), findsOneWidget);

    // Демо-ответ собеседника приходит через ~1 секунду.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('А?'), findsWidgets);
  });

  testWidgets('стенка: новый пост появляется в «Моё!»', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Вкладка «Стенка» в нижней навигации.
    final wallIcon = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/nav_wall.png');
    await tester.tap(wallIcon);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Новый пост?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Мой первый пост!');
    await tester.tap(find.text('Новый пост!'));
    await tester.pumpAndSettle();

    // Вернулись на стенку, пост виден в «Моё!».
    expect(find.text('Мой первый пост!'), findsOneWidget);
  });

  testWidgets('поиск человека → новый чат → сообщение', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // «+» в шапке чатов открывает поиск.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Новый чат'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'panda');
    await tester.pump(const Duration(milliseconds: 600)); // debounce + поиск
    await tester.pumpAndSettle();
    expect(find.text('@de.panda'), findsOneWidget);

    await tester.tap(find.text('Denis Panda'));
    await tester.pumpAndSettle();

    // Открылся пустой диалог, отправляем первое сообщение.
    await tester.enterText(find.byType(TextField).last, 'привет, панда');
    await tester.tap(find.text('А?'));
    await tester.pump();
    expect(find.text('привет, панда'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // демо-ответ

    // Чат появился в списке.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Denis Panda'), findsOneWidget);
  });

  testWidgets('приватность: выбор сохраняется в репозиторий', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Настройки → «Настройки стены» → экран приватности.
    final settingsIcon = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/nav_settings.png');
    await tester.tap(settingsIcon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки стены'));
    await tester.pumpAndSettle();

    // «Кто видит мою стену?»: по умолчанию «Все», переключаем на «Я».
    await tester.tap(find.text('Я').first);
    await tester.pumpAndSettle();
    expect((await privacyRepository.load()).wallVisibleTo, Audience.me);

    // После перезахода выбранное значение на месте.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки стены'));
    await tester.pumpAndSettle();
    expect((await privacyRepository.load()).wallVisibleTo, Audience.me);
  });
}
