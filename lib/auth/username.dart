/// Правила для @ника. Зеркалируют constraint `username_format`
/// в supabase/schema.sql — меняются только вместе.
library;

final _usernameRe = RegExp(r'^[a-z0-9](\.?[a-z0-9_])*$');

const usernameMinLength = 3;
const usernameMaxLength = 30;

/// Возвращает текст ошибки или null, если ник корректен.
String? validateUsernameFormat(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return 'Введи ник';
  if (value.length < usernameMinLength) {
    return 'Минимум $usernameMinLength символа';
  }
  if (value.length > usernameMaxLength) {
    return 'Максимум $usernameMaxLength символов';
  }
  if (value.endsWith('.')) return 'Точка не может быть последней';
  if (!_usernameRe.hasMatch(value)) {
    return 'Только латиница, цифры, точка и подчёркивание;\n'
        'без точек подряд и в начале';
  }
  return null;
}

String? validateEmail(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Введи почту';
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!re.hasMatch(value)) return 'Это не похоже на почту';
  return null;
}

String? validatePassword(String value) {
  if (value.isEmpty) return 'Введи пароль';
  if (value.length < 8) return 'Минимум 8 символов';
  return null;
}
