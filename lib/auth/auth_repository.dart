import 'dart:async';

/// Профиль пользователя в системе «А?».
class Profile {
  const Profile({this.username, this.displayName});

  /// null, пока пользователь не выбрал ник (шаг онбординга).
  final String? username;
  final String? displayName;
}

/// Текущее состояние авторизации.
class AuthSnapshot {
  const AuthSnapshot({required this.userId, required this.email, this.profile});

  final String userId;
  final String email;
  final Profile? profile;

  bool get needsUsername => profile?.username == null;
}

/// Ошибка авторизации с человекочитаемым сообщением для UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Контракт бэкенда авторизации.
///
/// Флоу: signUp → письмо → пользователь подтверждает почту → signIn →
/// если username ещё не выбран, claimUsername → готово.
abstract class AuthRepository {
  /// null — не залогинен. Стрим шлёт текущее значение новым подписчикам.
  Stream<AuthSnapshot?> get snapshots;

  AuthSnapshot? get current;

  /// Восстановление сессии при старте приложения.
  Future<void> init();

  /// Регистрирует и отправляет письмо подтверждения.
  /// Сессию НЕ создаёт — вход возможен только после подтверждения почты.
  Future<void> signUp({required String email, required String password});

  /// [identifier] — почта или @ник.
  Future<void> signIn({required String identifier, required String password});

  Future<void> signOut();

  Future<void> resendConfirmation(String email);

  Future<void> requestPasswordReset(String email);

  /// Свободен ли ник (формат проверяется отдельно, validateUsernameFormat).
  Future<bool> isUsernameAvailable(String username);

  /// Закрепляет ник и имя за текущим пользователем.
  /// Бросает [AuthFailure], если ник заняли раньше (гонка).
  Future<void> claimUsername({
    required String username,
    required String displayName,
  });
}

/// Единая точка доступа; назначается в main() до runApp.
late final AuthRepository authRepository;
