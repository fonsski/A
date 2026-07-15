import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a_messenger/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('тема восстанавливается и сохраняется', () async {
    SharedPreferences.setMockInitialValues({'theme': 'dark'});
    final prefs = await SharedPreferences.getInstance();

    await initTheme(prefs);
    expect(themeMode.value, ThemeMode.dark);

    themeMode.value = ThemeMode.light;
    await Future<void>.delayed(Duration.zero); // listener пишет асинхронно
    expect(prefs.getString('theme'), 'light');

    themeMode.value = ThemeMode.dark;
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString('theme'), 'dark');
  });
}
