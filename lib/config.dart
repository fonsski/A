import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Конфигурация бэкенда.
///
/// Пока URL пустой — приложение работает на мок-репозитории (без сети).
/// Когда создадите проект на supabase.com, запускайте так:
///
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
abstract final class AppConfig {
  /// Версия приложения; держим равной `version` в pubspec.yaml (без «+сборка»),
  /// это проверяет test/version_test.dart.
  static const version = '0.0.3';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get useSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// URL-схема приложения на мобильных платформах и macOS. Прописана в
  /// ios/Runner/Info.plist, macos/Runner/Info.plist и AndroidManifest.xml.
  static const urlScheme = 'com.fonsski.amessenger';

  /// Куда Supabase вернёт пользователя по ссылке из письма восстановления.
  /// Этот адрес должен быть в Authentication → URL Configuration → Redirect
  /// URLs. `null` — на платформе нет обработки ссылок (Windows, Linux):
  /// тогда Supabase использует Site URL.
  static String? get passwordResetRedirect {
    if (kIsWeb) return Uri.base.origin;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => '$urlScheme://reset-password',
      _ => null,
    };
  }
}
