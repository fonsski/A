import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_repository.dart';
import 'auth/mock_auth_repository.dart';
import 'auth/supabase_auth_repository.dart';
import 'config.dart';
import 'data/chat_repository.dart';
import 'data/friends_repository.dart';
import 'data/mock/mock_chat_repository.dart';
import 'data/mock/mock_friends_repository.dart';
import 'data/mock/mock_wall_repository.dart';
import 'data/presence_repository.dart';
import 'data/privacy_repository.dart';
import 'data/supabase/supabase_chat_repository.dart';
import 'data/supabase/supabase_friends_repository.dart';
import 'data/supabase/supabase_presence_repository.dart';
import 'data/supabase/supabase_privacy_repository.dart';
import 'data/supabase/supabase_wall_repository.dart';
import 'data/wall_repository.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

/// Переключается кнопкой «DARK» на экране чатов.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.useSupabase) {
    debugPrint('А?: Supabase.initialize starting...');
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // Принимает и новый publishable-ключ, и легаси anon-ключ.
      publishableKey: AppConfig.supabaseAnonKey,
    );
    debugPrint('А?: Supabase.initialize done');
    authRepository = SupabaseAuthRepository();
    chatRepository = SupabaseChatRepository();
    wallRepository = SupabaseWallRepository();
    privacyRepository = SupabasePrivacyRepository();
    friendsRepository = SupabaseFriendsRepository();
    presenceRepository = SupabasePresenceRepository();
  } else {
    authRepository = MockAuthRepository();
    chatRepository = MockChatRepository();
    wallRepository = MockWallRepository();
    privacyRepository = MockPrivacyRepository();
    friendsRepository = MockFriendsRepository();
    presenceRepository = MockPresenceRepository();
  }
  await authRepository.init();
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
          home: const SplashScreen(),
        );
      },
    );
  }
}
