import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _wall = <String, int>{
    'Кто видит мою стену?': 1,
    'Кто может оставлять записи на стене?': 0,
    'Кто может комментировать мои записи?': 1,
  };
  final _security = <String, int>{
    'Кто видит мой номер?': 1,
    'Кто видит статус в сети?': 0,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: AHeader(
                title: 'Приватность и конфиденциальность',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild:
                    Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  const _SectionTitle('Настройки стены'),
                  for (final entry in _wall.entries)
                    _SegmentedRow(
                      question: entry.key,
                      selected: entry.value,
                      onChanged: (i) => setState(() => _wall[entry.key] = i),
                    ),
                  const SizedBox(height: 16),
                  const _SectionTitle('Общая безопасность'),
                  for (final entry in _security.entries)
                    _SegmentedRow(
                      question: entry.key,
                      selected: entry.value,
                      onChanged: (i) =>
                          setState(() => _security[entry.key] = i),
                    ),
                  const _ActionRow(
                      question: 'Черный список', action: 'Показать'),
                  const _ActionRow(
                      question: 'Код для входа в приложение',
                      action: 'Изменить'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 1, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Вопрос + пилюля с сегментами «Все / Друзья / Я».
class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.question,
    required this.selected,
    required this.onChanged,
  });

  static const _options = ['Все', 'Друзья', 'Я'];

  final String question;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 8),
            child: Text(
              question,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: pillDecoration(colors.surface),
            child: Row(
              children: [
                for (var i = 0; i < _options.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: i == selected
                            ? BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 4,
                                    offset: Offset(0, -2),
                                  ),
                                ],
                              )
                            : null,
                        child: Text(
                          _options[i],
                          style: TextStyle(
                            color: i == selected
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.question, required this.action});

  final String question;
  final String action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 8),
            child: Text(
              question,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: pillDecoration(colors.surface),
            child: Text(
              action,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
