import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../theme.dart';

/// Экран запуска: показывается сразу, пока main() готовит приложение.
/// Если шаг запуска завис или упал, видно, на каком именно, — вместо
/// пустого белого экрана.
class BootApp extends StatelessWidget {
  const BootApp({super.key, required this.step, required this.error});

  /// Текущий шаг запуска.
  final ValueListenable<String> step;

  /// Текст ошибки запуска или null.
  final ValueListenable<String?> error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'А?',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder<String?>(
              valueListenable: error,
              builder: (context, err, _) => ValueListenableBuilder<String>(
                valueListenable: step,
                builder: (context, current, _) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        err == null ? 'Запуск…' : 'Не удалось запустить «А?»',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text('Шаг: $current'),
                      if (err != null) ...[
                        const SizedBox(height: 12),
                        SelectableText(err),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
