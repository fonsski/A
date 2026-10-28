import 'package:flutter/material.dart';

import '../theme.dart';

/// Показывается вместо приложения, если оно собрано без ключей Supabase.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'А?',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: const MissingConfigScreen(),
    );
  }
}

class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  static const command = './run.sh macos';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Нет ключей Supabase', style: text.headlineSmall),
                  const SizedBox(height: 12),
                  const Text(
                    'Приложение запущено без SUPABASE_URL и SUPABASE_ANON_KEY, '
                    'поэтому письма и вход не работают. Запустите его с '
                    'ключами:',
                  ),
                  const SizedBox(height: 12),
                  const SelectableText(command),
                  const SizedBox(height: 12),
                  const Text(
                    'Скрипт читает dart_defines.json (образец — '
                    'dart_defines.example.json).',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
