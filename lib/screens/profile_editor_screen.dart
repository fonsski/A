import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class ProfileEditorScreen extends StatelessWidget {
  const ProfileEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: pillDecoration(
                        colors.surface,
                        borderColor: colors.accent,
                      ),
                      child: Icon(Icons.arrow_back,
                          color: colors.accent, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: pillDecoration(colors.accent),
                      child: Text(
                        'Редактор профиля',
                        style: TextStyle(
                          color: colors.bg,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 36,
                    height: 36,
                    padding: const EdgeInsets.all(2),
                    decoration: pillDecoration(
                      colors.surface,
                      borderColor: colors.accent,
                    ),
                    child: const AAvatar(size: 32),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _EditorField(
                          label: 'Имя?',
                          hint: 'Вася Пупкин',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Фото?',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(12),
                            decoration: pillDecoration(colors.surface),
                            child: Image.asset('assets/images/react_3.png'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _EditorField(label: 'Имя пользователя?', hint: 'vasok'),
                  const SizedBox(height: 24),
                  _EditorField(label: 'О себе?', hint: 'жестка чувствую'),
                  const SizedBox(height: 24),
                  _EditorField(
                    label: 'Ссылки на другие соц. сети?',
                    hint: 'TG:@vasya',
                  ),
                  const SizedBox(height: 24),
                  _EditorField(
                    label: 'Номер телефона?',
                    hint: '+7 900 000-00-00',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 1, bottom: 8),
          child: Text(
            label,
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: pillDecoration(colors.surface),
          child: Center(
            child: TextField(
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hint,
                hintStyle: TextStyle(color: colors.hint, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
