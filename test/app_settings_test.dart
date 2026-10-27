import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:a_messenger/screens/faq_screen.dart';
import 'package:a_messenger/screens/settings_screen.dart';
import 'package:a_messenger/settings/app_settings.dart';
import 'package:a_messenger/theme.dart';

Widget _app(Widget home) => MaterialApp(
  theme: ThemeData(extensions: const [AColors.light]),
  home: Scaffold(body: home),
);

void main() {
  group('AppSettings', () {
    test('значения по умолчанию', () {
      final s = AppSettings();
      expect(s.fontScale, 1.0);
      expect(s.autoloadMedia, isTrue);
      expect(s.chatBackgroundFor(Brightness.light), isNull);
    });

    test('сохраняет и восстанавливает настройки', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = AppSettings();
      await first.load(prefs);
      await first.setFontSizeIndex(3);
      await first.setChatBackgroundIndex(2);
      await first.setAutoloadMedia(false);

      final second = AppSettings();
      await second.load(prefs);
      expect(second.fontSizeIndex, 3);
      expect(second.fontScale, kFontSizeOptions[3].scale);
      expect(second.chatBackgroundIndex, 2);
      expect(second.chatBackgroundFor(Brightness.dark), isNotNull);
      expect(second.autoloadMedia, isFalse);
    });

    test(
      'битый индекс из настроек заменяется значением по умолчанию',
      () async {
        SharedPreferences.setMockInitialValues({
          kFontSizePref: 99,
          kChatBackgroundPref: -1,
        });
        final s = AppSettings();
        await s.load(await SharedPreferences.getInstance());
        expect(s.fontSizeIndex, 1);
        expect(s.chatBackgroundIndex, 0);
      },
    );

    test('слушатели получают уведомление об изменении', () async {
      final s = AppSettings();
      var calls = 0;
      s.addListener(() => calls++);
      await s.setAutoloadMedia(false);
      expect(calls, 1);
    });
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 Б');
    expect(formatBytes(1536), '1.5 КБ');
    expect(formatBytes(3 * 1024 * 1024), '3.0 МБ');
  });

  group('экран настроек', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Глобальный синглтон: возвращаем значения по умолчанию.
      appSettings
        ..setFontSizeIndex(1)
        ..setChatBackgroundIndex(0)
        ..setAutoloadMedia(true);
    });

    testWidgets('выбор размера шрифта меняет значение', (tester) async {
      await tester.pumpWidget(_app(const SettingsScreen()));
      // «Обычный» — и размер шрифта, и фон чатов.
      expect(find.text('Обычный'), findsNWidgets(2));

      await tester.tap(find.text('Размер шрифта'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Крупный'));
      await tester.pumpAndSettle();

      expect(appSettings.fontSizeIndex, 2);
      expect(find.text('Крупный'), findsOneWidget);
    });

    testWidgets('выбор фона чата', (tester) async {
      await tester.pumpWidget(_app(const SettingsScreen()));
      await tester.tap(find.text('Фон чатов'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Голубой'));
      await tester.pumpAndSettle();

      expect(appSettings.chatBackgroundIndex, 2);
    });

    testWidgets('автозагрузка медиа переключается', (tester) async {
      await tester.pumpWidget(_app(const SettingsScreen()));
      await tester.scrollUntilVisible(
        find.text('Автозагрузка медиа'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Автозагрузка медиа'));
      await tester.pump();
      expect(appSettings.autoloadMedia, isFalse);
    });

    testWidgets('использование памяти показывает кэш и очищает его', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SettingsScreen()));
      await tester.scrollUntilVisible(
        find.text('Использование памяти'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Использование памяти'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Кэш изображений'), findsOneWidget);

      await tester.tap(find.text('Очистить'));
      await tester.pumpAndSettle();
      expect(find.text('Кэш очищен'), findsOneWidget);
    });

    testWidgets('FAQ открывается из настроек и раскрывает ответ', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SettingsScreen()));
      await tester.scrollUntilVisible(
        find.text('Помощь / FAQ'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Помощь / FAQ'));
      await tester.pumpAndSettle();
      expect(find.byType(FaqScreen), findsOneWidget);

      final first = kFaqItems.first;
      expect(find.text(first.answer), findsNothing);
      await tester.tap(find.text(first.question));
      await tester.pumpAndSettle();
      expect(find.text(first.answer), findsOneWidget);
    });
  });
}
