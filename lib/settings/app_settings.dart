import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Размер текста сообщений: подпись в настройках и множитель.
class FontSizeOption {
  const FontSizeOption(this.label, this.scale);

  final String label;
  final double scale;
}

const kFontSizeOptions = [
  FontSizeOption('Мелкий', 0.875),
  FontSizeOption('Обычный', 1.0),
  FontSizeOption('Крупный', 1.125),
  FontSizeOption('Очень крупный', 1.25),
];

/// Фон экрана чата. Цвет `null` — обычный фон темы.
class ChatBackgroundOption {
  const ChatBackgroundOption(this.label, {this.light, this.dark});

  final String label;
  final Color? light;
  final Color? dark;

  Color? colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

const kChatBackgrounds = [
  ChatBackgroundOption('Обычный'),
  ChatBackgroundOption(
    'Розовый',
    light: Color(0xFFFDEFF0),
    dark: Color(0xFF241416),
  ),
  ChatBackgroundOption(
    'Голубой',
    light: Color(0xFFEAF3FB),
    dark: Color(0xFF121A22),
  ),
  ChatBackgroundOption(
    'Зелёный',
    light: Color(0xFFEDF6EE),
    dark: Color(0xFF131C14),
  ),
  ChatBackgroundOption(
    'Сиреневый',
    light: Color(0xFFF2EEF9),
    dark: Color(0xFF1A1622),
  ),
];

const kFontSizePref = 'font_size_index';
const kChatBackgroundPref = 'chat_background_index';
const kAutoloadMediaPref = 'autoload_media';

/// Пользовательские настройки интерфейса, которые хранятся на устройстве.
/// Значения по умолчанию действуют, пока [load] не вызвали (например, в тестах).
class AppSettings extends ChangeNotifier {
  SharedPreferences? _prefs;
  var _fontSizeIndex = 1;
  var _chatBackgroundIndex = 0;
  var _autoloadMedia = true;

  int get fontSizeIndex => _fontSizeIndex;
  int get chatBackgroundIndex => _chatBackgroundIndex;

  /// Автоматически показывать фото в чатах. Выключено — фото открывается
  /// по нажатию.
  bool get autoloadMedia => _autoloadMedia;

  double get fontScale => kFontSizeOptions[_fontSizeIndex].scale;

  /// Цвет фона чата для текущей темы; `null` — взять фон темы.
  Color? chatBackgroundFor(Brightness brightness) =>
      kChatBackgrounds[_chatBackgroundIndex].colorFor(brightness);

  Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    _fontSizeIndex = _clamp(
      prefs.getInt(kFontSizePref),
      kFontSizeOptions.length,
      1,
    );
    _chatBackgroundIndex = _clamp(
      prefs.getInt(kChatBackgroundPref),
      kChatBackgrounds.length,
      0,
    );
    _autoloadMedia = prefs.getBool(kAutoloadMediaPref) ?? true;
    notifyListeners();
  }

  /// Индекс из настроек мог остаться от другой версии списка.
  static int _clamp(int? value, int length, int fallback) =>
      value != null && value >= 0 && value < length ? value : fallback;

  Future<void> setFontSizeIndex(int index) async {
    _fontSizeIndex = _clamp(index, kFontSizeOptions.length, 1);
    notifyListeners();
    await _prefs?.setInt(kFontSizePref, _fontSizeIndex);
  }

  Future<void> setChatBackgroundIndex(int index) async {
    _chatBackgroundIndex = _clamp(index, kChatBackgrounds.length, 0);
    notifyListeners();
    await _prefs?.setInt(kChatBackgroundPref, _chatBackgroundIndex);
  }

  Future<void> setAutoloadMedia(bool value) async {
    _autoloadMedia = value;
    notifyListeners();
    await _prefs?.setBool(kAutoloadMediaPref, value);
  }
}

final appSettings = AppSettings();
