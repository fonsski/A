import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/config.dart';
import 'package:a_messenger/screens/missing_config_screen.dart';

void main() {
  testWidgets('без ключей показывается экран с командой запуска', (
    tester,
  ) async {
    await tester.pumpWidget(const MissingConfigApp());
    expect(find.text('Нет ключей Supabase'), findsOneWidget);
    expect(find.text(MissingConfigScreen.command), findsOneWidget);
  });

  test('в тестовой сборке ключей нет', () {
    expect(AppConfig.hasSupabaseKeys, isFalse);
  });
}
