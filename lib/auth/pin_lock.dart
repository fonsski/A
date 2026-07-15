import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальный код для входа в приложение (как код-пароль в Telegram).
/// Хранится только хэш с солью; сам код никуда не отправляется.
class PinLock {
  PinLock(this._prefs) {
    locked.value = hasPin;
  }

  static const _hashKey = 'pin_hash';
  static const _saltKey = 'pin_salt';

  final SharedPreferences _prefs;

  /// true — приложение заперто и ждёт код (сбрасывается при перезапуске).
  final locked = ValueNotifier<bool>(false);

  bool get hasPin => _prefs.containsKey(_hashKey);

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final salt = List.generate(16, (_) => Random.secure().nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _prefs.setString(_saltKey, salt);
    await _prefs.setString(_hashKey, _hash(pin, salt));
  }

  /// Проверяет код; при успехе отпирает приложение.
  bool unlock(String pin) {
    final salt = _prefs.getString(_saltKey);
    final hash = _prefs.getString(_hashKey);
    if (salt == null || hash == null) return true;
    final ok = _hash(pin, salt) == hash;
    if (ok) locked.value = false;
    return ok;
  }

  Future<void> clear() async {
    await _prefs.remove(_hashKey);
    await _prefs.remove(_saltKey);
    locked.value = false;
  }
}

/// Назначается в main() до runApp.
late final PinLock pinLock;
