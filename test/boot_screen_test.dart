import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/screens/boot_screen.dart';

void main() {
  testWidgets('экран запуска показывает шаг, а при сбое — ошибку', (
    tester,
  ) async {
    final step = ValueNotifier<String>('Supabase.initialize');
    final error = ValueNotifier<String?>(null);
    await tester.pumpWidget(BootApp(step: step, error: error));
    expect(find.text('Запуск…'), findsOneWidget);
    expect(find.text('Шаг: Supabase.initialize'), findsOneWidget);

    error.value = 'Exception: нет сети';
    await tester.pump();
    expect(find.text('Не удалось запустить «А?»'), findsOneWidget);
    expect(find.text('Exception: нет сети'), findsOneWidget);
  });
}
