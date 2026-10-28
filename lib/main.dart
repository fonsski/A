import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_repository.dart';
import 'auth/pin_lock.dart';
import 'auth/supabase_auth_repository.dart';
import 'config.dart';
import 'data/chat_repository.dart';
import 'data/friends_repository.dart';
import 'data/presence_repository.dart';
import 'data/privacy_repository.dart';
import 'data/reaction_usage.dart';
import 'data/supabase/supabase_chat_repository.dart';
import 'data/supabase/supabase_friends_repository.dart';
import 'data/supabase/supabase_presence_repository.dart';
import 'data/supabase/supabase_privacy_repository.dart';
import 'data/supabase/supabase_wall_repository.dart';
import 'data/wall_repository.dart';
import 'calls/call_engine.dart';
import 'calls/call_service.dart';
import 'calls/supabase_call_signaling.dart';
import 'media/audio_backend.dart';
import 'media/circle_camera.dart';
import 'media/voice_player.dart';
import 'media/voice_recorder.dart';
import 'notifications/notification_service.dart';
import 'data/models.dart';
import 'screens/boot_screen.dart';
import 'screens/call_screen.dart';
import 'screens/missing_config_screen.dart';
import 'screens/splash_screen.dart';
import 'settings/app_settings.dart';
import 'theme.dart';

/// Переключается кнопкой «DARK» на экране чатов и строкой «Тема» в настройках.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Восстанавливает сохранённую тему и сохраняет каждое переключение.
Future<void> initTheme(SharedPreferences prefs) async {
  themeMode.value = prefs.getString('theme') == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;
  themeMode.addListener(() {
    prefs.setString(
      'theme',
      themeMode.value == ThemeMode.dark ? 'dark' : 'light',
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Экран запуска показывается сразу: если шаг ниже завис или упал, на
  // телефоне видно какой, а не белый экран.
  final step = ValueNotifier<String>('начало');
  final error = ValueNotifier<String?>(null);
  runApp(BootApp(step: step, error: error));
  try {
    await _boot(step);
  } catch (e, st) {
    debugPrint('А?: запуск не удался: $e\n$st');
    error.value = '$e\n\n$st';
  }
}

Future<void> _boot(ValueNotifier<String> step) async {
  step.value = 'SharedPreferences';
  final prefs = await SharedPreferences.getInstance();
  step.value = 'тема и настройки';
  await initTheme(prefs);
  await appSettings.load(prefs);
  step.value = 'голос и камера';
  pinLock = PinLock(prefs);
  reactionUsage = ReactionUsage(prefs);
  voicePlayer = VoicePlayerController(AudioplayersBackend());
  voiceRecorder = RecordPackageVoiceRecorder();
  circleCameraFactory = CameraPackageCircleCamera.new;
  // Без ключей приложение не запускается: мок-режим только для тестов, иначе
  // письма (восстановление пароля, подтверждение) молча не уходят.
  if (!AppConfig.hasSupabaseKeys) {
    runApp(const MissingConfigApp());
    return;
  }
  step.value = 'Supabase.initialize';
  debugPrint('А?: Supabase.initialize starting...');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // Принимает и новый publishable-ключ, и легаси anon-ключ.
    publishableKey: AppConfig.supabaseAnonKey,
  );
  debugPrint('А?: Supabase.initialize done');
  step.value = 'репозитории и звонки';
  authRepository = SupabaseAuthRepository();
  chatRepository = SupabaseChatRepository();
  wallRepository = SupabaseWallRepository();
  privacyRepository = SupabasePrivacyRepository();
  friendsRepository = SupabaseFriendsRepository();
  presenceRepository = SupabasePresenceRepository();
  callService = CallService(
    signaling: SupabaseCallSignaling(),
    engineFactory: WebRtcCallEngine.new,
    self: () {
      final auth = authRepository.current;
      return UserSummary(
        id: auth?.userId ?? '',
        username: auth?.profile?.username ?? '',
        displayName:
            auth?.profile?.displayName ?? auth?.profile?.username ?? '',
        avatarUrl: auth?.profile?.avatarUrl,
      );
    },
  );
  step.value = 'вход (сессия)';
  await authRepository.init();
  notificationService = NotificationService(prefs)..init();
  runApp(const AMessengerApp());
}

class AMessengerApp extends StatelessWidget {
  const AMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'А?',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          // Звонок поверх всех экранов: полный экран или «островок».
          builder: (context, child) =>
              CallOverlay(child: child ?? const SizedBox.shrink()),
          home: const SplashScreen(),
        );
      },
    );
  }
}
