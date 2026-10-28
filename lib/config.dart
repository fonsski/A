import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Конфигурация бэкенда.
///
/// Ключи Supabase обязательны: без них приложение показывает экран
/// «Нет ключей» и не запускается (мок-репозитории остались только для тестов).
/// Запускать через `./run.sh` или так:
///
/// flutter run -d macos --dart-define-from-file=dart_defines.json
abstract final class AppConfig {
  /// Версия приложения; держим равной `version` в pubspec.yaml (без «+сборка»),
  /// это проверяет test/version_test.dart.
  static const version = '0.0.4';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabaseKeys =>
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
