import 'package:flutter/material.dart';

import '../auth/pin_lock.dart';
import '../data/presence_repository.dart';
import '../data/privacy_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'blacklist_screen.dart';

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

  Future<void> _update(PrivacySettings updated) async {
    // Оптимистично: UI сразу, база следом.
    setState(() => _settings = updated);
    await privacyRepository.save(updated);
  }

  Future<void> _changePin(BuildContext context) async {
    final colors = context.colors;
    final current = TextEditingController();
    final fresh = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Код для входа',
            style: TextStyle(color: colors.textPrimary, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pinLock.hasPin)
              TextField(
                controller: current,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(hintText: 'Текущий код'),
              ),
            TextField(
              controller: fresh,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  hintText: 'Новый код (пусто — убрать)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child:
                Text('Отмена', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text('Сохранить',
                style: TextStyle(
                    color: colors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;

    if (pinLock.hasPin && !pinLock.unlock(current.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текущий код неверный')));
      return;
    }
    final newPin = fresh.text.trim();
    if (newPin.isEmpty) {
      await pinLock.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Код убран')));
      }
    } else if (newPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Код — минимум 4 символа')));
      return;
    } else {
      await pinLock.setPin(newPin);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Код установлен — спросим при следующем входе')));
      }
    }
    setState(() {}); // обновить подпись Установить/Изменить
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
                          question:
                              'Кто видит статус в сети?\n(«Я» — скроешь свой, но и чужой не увидишь)',
                          selected: s.onlineVisibleTo.index,
                          onChanged: (i) async {
                            await _update(s.copyWith(
                                onlineVisibleTo: Audience.values[i]));
                            // Presence перечитывает видимость сразу.
                            await presenceRepository.refreshVisibility();
                          },
                        ),
                        _ActionRow(
                          question: 'Черный список',
                          action: 'Показать',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const BlacklistScreen()),
                          ),
                        ),
                        _ActionRow(
                          question: 'Код для входа в приложение',
                          action: pinLock.hasPin ? 'Изменить' : 'Установить',
                          onTap: () => _changePin(context),
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
  const _ActionRow({
    required this.question,
    required this.action,
    this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback? onTap;

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
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: pillDecoration(colors.surface),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      action,
                      style:
                          TextStyle(color: colors.textPrimary, fontSize: 16),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: colors.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
