import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/auth/pin_lock.dart';
import 'package:a_messenger/data/chat_repository.dart';
import 'package:a_messenger/data/friends_repository.dart';
import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/mock/mock_friends_repository.dart';
import 'package:a_messenger/data/mock/mock_wall_repository.dart';
import 'package:a_messenger/data/presence_repository.dart';
import 'package:a_messenger/data/privacy_repository.dart';
import 'package:a_messenger/data/wall_repository.dart';
import 'package:a_messenger/screens/user_profile_screen.dart';
import 'package:a_messenger/main.dart';
import 'package:a_messenger/screens/auth/confirm_email_screen.dart';
import 'package:a_messenger/screens/auth/login_screen.dart';
import 'package:a_messenger/screens/auth/pick_username_screen.dart';
import 'package:a_messenger/screens/auth/signup_screen.dart';
import 'package:a_messenger/screens/auth/pin_lock_screen.dart';
import 'package:a_messenger/screens/blacklist_screen.dart';
import 'package:a_messenger/screens/chat_info_screen.dart';
import 'package:a_messenger/screens/home_shell.dart';
import 'package:a_messenger/screens/photo_view_screen.dart';
import 'package:a_messenger/screens/profile_editor_screen.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    pinLock = PinLock(await SharedPreferences.getInstance());
    authRepository = MockAuthRepository(
      confirmDelay: const Duration(seconds: 1),
    );
    chatRepository = MockChatRepository();
    wallRepository = MockWallRepository();
    privacyRepository = MockPrivacyRepository();
    friendsRepository = MockFriendsRepository();
    presenceRepository = MockPresenceRepository();
  });

  testWidgets('splash → экран входа (сессии нет)', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    expect(find.byType(Image), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Войти!'), findsOneWidget);
  });

  testWidgets('полный флоу: регистрация → почта → вход → ник → приложение', (
    tester,
  ) async {
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

  testWidgets('чат: отправка сообщения, автоответ и фокус на поле ввода', (
    tester,
  ) async {
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

    // Фокус не потерян — можно печатать следующее сообщение сразу.
    final input = tester.widget<TextField>(find.byType(TextField).last);
    expect(input.focusNode!.hasFocus, isTrue);

    // Демо-ответ собеседника приходит через ~1 секунду.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('А?'), findsWidgets);
  });

  testWidgets('фото открывается на полный экран и закрывается', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Viktor Dudovich'));
    await tester.pumpAndSettle();

    // Тап по фото в пузыре — полноэкранный просмотр.
    final photo = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/media.png',
    );
    await tester.ensureVisible(photo.first);
    await tester.pumpAndSettle();
    await tester.tap(photo.first);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewScreen), findsNothing);
  });

  testWidgets('инфо о чате: открытие по шапке, плашка звонка сворачивается', (
    tester,
  ) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Viktor Dudovich'));
    await tester.pumpAndSettle();
    // Тап по шапке чата открывает развёрнутую информацию.
    await tester.tap(find.text('Viktor Dudovich'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatInfoScreen), findsOneWidget);
    expect(find.text('в сети'), findsOneWidget);
    expect(find.text('Звонок'), findsOneWidget);

    // «Звонок» разворачивает плашку Аудио/Видео (group 10).
    await tester.tap(find.text('Звонок'));
    await tester.pumpAndSettle();
    expect(find.text('Аудио'), findsOneWidget);
    expect(find.text('Видео'), findsWidgets); // кнопка + вкладка медиа
    expect(find.text('Звонок'), findsNothing);

    // Стрелка посередине сворачивает обратно.
    await tester.tap(find.byIcon(Icons.reply));
    await tester.pumpAndSettle();
    expect(find.text('Звонок'), findsOneWidget);
    expect(find.text('Аудио'), findsNothing);

    // «Чат» возвращает в переписку.
    await tester.tap(find.text('Чат'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatInfoScreen), findsNothing);
    expect(find.text('Сообщение'), findsOneWidget);
  });

  testWidgets('стенка: новый пост появляется в «Моё!»', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Вкладка «Стенка» в нижней навигации.
    final wallIcon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/nav_wall.png',
    );
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

    // «Человечек+» в шапке чатов открывает поиск.
    await tester.tap(find.byIcon(Icons.person_add_alt_1));
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

  testWidgets('редактор профиля: имя сохраняется и видно в профиле', (
    tester,
  ) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final profileIcon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/nav_profile.png',
    );
    await tester.tap(profileIcon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Тестовое Имя');
    // Сохранение — галочкой в шапке.
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    // Редактор закрылся, в профиле новое имя (и оно же в репозитории).
    expect(find.byType(ProfileEditorScreen), findsNothing);
    expect(find.text('Тестовое Имя'), findsOneWidget);
    expect(authRepository.current!.profile!.displayName, 'Тестовое Имя');
  });

  testWidgets('друзья: принять заявку из профиля', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Профиль → счётчик друзей с бейджем заявки → экран друзей.
    final profileIcon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/nav_profile.png',
    );
    await tester.tap(profileIcon);
    await tester.pumpAndSettle();
    expect(find.textContaining('заявка'), findsOneWidget);
    await tester.tap(find.textContaining('друг'));
    await tester.pumpAndSettle();

    // Trofim More во входящих — принимаем.
    expect(find.text('Заявки'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Заявки'), findsNothing);
    // Теперь друзей двое: Viktor Dudovich и Trofim More.
    expect(find.text('Trofim More'), findsOneWidget);
    expect(find.text('Viktor Dudovich'), findsOneWidget);
  });

  testWidgets('страница друга: профиль, статус «в сети» и его стена', (
    tester,
  ) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Профиль → друзья → тап по другу открывает его страницу.
    final profileIcon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/nav_profile.png',
    );
    await tester.tap(profileIcon);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('друг'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viktor Dudovich'));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfileScreen), findsOneWidget);
    expect(find.text('@viktor.dud'), findsOneWidget);
    expect(find.text('в сети'), findsOneWidget); // u1 онлайн в моке
    expect(find.text('В друзьях'), findsOneWidget);
    // Его стена: пост про казино от viktor.dud.
    expect(find.textContaining('казино'), findsOneWidget);
  });

  testWidgets('чёрный список открывается из приватности', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final settingsIcon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/nav_settings.png',
    );
    await tester.tap(settingsIcon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки стены'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Показать'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();
    expect(find.byType(BlacklistScreen), findsOneWidget);
    expect(find.text('Список пуст — и это прекрасно'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
  });

  testWidgets('PIN-замок: заперто до верного кода', (tester) async {
    await pinLock.setPin('4321');
    pinLock.locked.value = true;

    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(PinLockScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '0000');
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный код'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '4321');
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);

    await pinLock.clear();
  });

  testWidgets('приватность: выбор сохраняется в репозиторий', (tester) async {
    await tester.pumpWidget(const AMessengerApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Настройки → «Настройки стены» → экран приватности.
    final settingsIcon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/nav_settings.png',
    );
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
