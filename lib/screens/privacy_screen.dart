import 'package:flutter/material.dart';

import '../data/privacy_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  PrivacySettings? _settings;

  @override
  void initState() {
    super.initState();
    privacyRepository.load().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  void _update(PrivacySettings updated) {
    // Оптимистично: UI сразу, база следом.
    setState(() => _settings = updated);
    privacyRepository.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = _settings;
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
              child: s == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      children: [
                        const _SectionTitle('Настройки стены'),
                        _SegmentedRow(
                          question: 'Кто видит мою стену?',
                          selected: s.wallVisibleTo.index,
                          onChanged: (i) => _update(
                              s.copyWith(wallVisibleTo: Audience.values[i])),
                        ),
                        _SegmentedRow(
                          question: 'Кто может оставлять записи на стене?',
                          selected: s.wallPostBy.index,
                          onChanged: (i) => _update(
                              s.copyWith(wallPostBy: Audience.values[i])),
                        ),
                        _SegmentedRow(
                          question: 'Кто может комментировать мои записи?',
                          options: const ['Все', 'Друзья', 'Никто'],
                          selected: s.commentsBy.index,
                          onChanged: (i) => _update(
                              s.copyWith(commentsBy: Audience.values[i])),
                        ),
                        const SizedBox(height: 16),
                        const _SectionTitle('Общая безопасность'),
                        _SegmentedRow(
                          question: 'Кто видит мой номер?',
                          selected: s.phoneVisibleTo.index,
                          onChanged: (i) => _update(
                              s.copyWith(phoneVisibleTo: Audience.values[i])),
                        ),
                        _SegmentedRow(
                          question: 'Кто видит статус в сети?',
                          selected: s.onlineVisibleTo.index,
                          onChanged: (i) => _update(
                              s.copyWith(onlineVisibleTo: Audience.values[i])),
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
    this.options = const ['Все', 'Друзья', 'Я'],
  });

  final String question;
  final List<String> options;
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
                for (var i = 0; i < options.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: i == selected
                            ? pillDecoration(colors.card,
                                radius: 36, inset: const Offset(0, -2))
                            : null,
                        child: Text(
                          options[i],
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
