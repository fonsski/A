// Временная утилита: рендерит экраны в PNG для визуальной сверки с макетом.
// Запуск: flutter test test/screenshot_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/data/chat_repository.dart';
import 'package:a_messenger/data/friends_repository.dart';
import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/mock/mock_friends_repository.dart';
import 'package:a_messenger/data/mock/mock_wall_repository.dart';
import 'package:a_messenger/data/privacy_repository.dart';
import 'package:a_messenger/data/wall_repository.dart';
import 'package:a_messenger/screens/auth/confirm_email_screen.dart';
import 'package:a_messenger/screens/auth/login_screen.dart';
import 'package:a_messenger/screens/auth/pick_username_screen.dart';
import 'package:a_messenger/screens/auth/signup_screen.dart';
import 'package:a_messenger/screens/chat_info_screen.dart';
import 'package:a_messenger/screens/chat_screen.dart';
import 'package:a_messenger/screens/friends_screen.dart';
import 'package:a_messenger/screens/home_shell.dart';
import 'package:a_messenger/screens/new_chat_screen.dart';
import 'package:a_messenger/screens/new_post_screen.dart';
import 'package:a_messenger/screens/privacy_screen.dart';
import 'package:a_messenger/screens/profile_editor_screen.dart';
import 'package:a_messenger/theme.dart';

const _outDir =
    r'C:\Users\fon\AppData\Local\Temp\claude\C--Users-fon-projects-flutter-A\cf35cef7-9a57-4d19-8f8c-a404cc4cacba\scratchpad\screens';

final _boundaryKey = GlobalKey();

Widget _wrap(Widget home, {ThemeMode mode = ThemeMode.light}) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      home: home,
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  // Даём асинхронной декодировке картинок завершиться.
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 100),
        ));
    await tester.pump();
  }
  final boundary = _boundaryKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir\\$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    authRepository = MockAuthRepository();
    chatRepository = MockChatRepository();
    wallRepository = MockWallRepository();
    privacyRepository = MockPrivacyRepository();
    friendsRepository = MockFriendsRepository();
    Directory(_outDir).createSync(recursive: true);
    final fontData = rootBundle.load('assets/fonts/RobotoFlex.ttf');
    final loader = FontLoader('RobotoFlex')..addFont(fontData);
    await loader.load();
  });

  Future<void> prepare(WidgetTester tester, Widget home,
      {ThemeMode mode = ThemeMode.light}) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(home, mode: mode));
  }

  Finder navIcon(String asset) => find.byWidgetPredicate((w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == asset);

  testWidgets('splash', (tester) async {
    await prepare(tester, const _SplashOnly());
    await _capture(tester, '01_splash');
  });

  testWidgets('chats', (tester) async {
    await prepare(tester, const HomeShell());
    await _capture(tester, '02_chats');
  });

  testWidgets('chats dark', (tester) async {
    await prepare(tester, const HomeShell(), mode: ThemeMode.dark);
    await _capture(tester, '03_chats_dark');
  });

  testWidgets('chat', (tester) async {
    await prepare(
      tester,
      const ChatScreen(chatId: 'c1', name: 'Viktor Dudovich'),
    );
    await _capture(tester, '04_chat');
  });

  testWidgets('wall', (tester) async {
    await prepare(tester, const HomeShell());
    await tester.tap(navIcon('assets/images/nav_wall.png'));
    await tester.pump();
    await _capture(tester, '05_wall');
  });

  testWidgets('new post', (tester) async {
    await prepare(tester, const NewPostScreen());
    await _capture(tester, '06_new_post');
  });

  testWidgets('settings', (tester) async {
    await prepare(tester, const HomeShell());
    await tester.tap(navIcon('assets/images/nav_settings.png'));
    await tester.pump();
    await _capture(tester, '07_settings');
  });

  testWidgets('privacy', (tester) async {
    await prepare(tester, const PrivacyScreen());
    await _capture(tester, '08_privacy');
  });

  testWidgets('profile', (tester) async {
    await prepare(tester, const HomeShell());
    await tester.tap(navIcon('assets/images/nav_profile.png'));
    await tester.pump();
    await _capture(tester, '09_profile');
  });

  testWidgets('editor', (tester) async {
    await prepare(tester, const ProfileEditorScreen());
    await _capture(tester, '10_editor');
  });

  testWidgets('login', (tester) async {
    await prepare(tester, LoginScreen(onSignUpTap: () {}));
    await _capture(tester, '11_login');
  });

  testWidgets('signup', (tester) async {
    await prepare(
      tester,
      SignUpScreen(onLoginTap: () {}, onRegistered: (_) {}),
    );
    await _capture(tester, '12_signup');
  });

  testWidgets('confirm email', (tester) async {
    await prepare(
      tester,
      ConfirmEmailScreen(email: 'gnida@tvar.ru', onGoToLogin: () {}),
    );
    await _capture(tester, '13_confirm_email');
  });

  testWidgets('pick username', (tester) async {
    await prepare(tester, const PickUsernameScreen());
    await _capture(tester, '14_pick_username');
  });

  testWidgets('chat info', (tester) async {
    await prepare(tester, const ChatInfoScreen(name: 'Viktor Dudovich'));
    await _capture(tester, '18_chat_info');
  });

  testWidgets('chat info call bar', (tester) async {
    await prepare(tester, const ChatInfoScreen(name: 'Viktor Dudovich'));
    await tester.tap(find.text('Звонок'));
    await tester.pumpAndSettle();
    await _capture(tester, '19_chat_info_call');
  });

  testWidgets('friends', (tester) async {
    await prepare(tester, const FriendsScreen());
    await _capture(tester, '20_friends');
  });

  testWidgets('new chat search', (tester) async {
    await prepare(tester, const NewChatScreen());
    await tester.enterText(find.byType(TextField).first, 'viktor');
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, '17_new_chat_search');
  });
}

/// Сплэш без таймера навигации, чтобы тест не зависел от Timer.
class _SplashOnly extends StatelessWidget {
  const _SplashOnly();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9383A),
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Image.asset('assets/images/logo.png', width: 170, height: 170),
        ),
      ),
    );
  }
}
