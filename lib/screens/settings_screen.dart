import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void openPrivacy() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PrivacyScreen()),
        );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 0),
          child: AHeader(title: 'Настройки'),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            children: [
              const _SectionTitle('Приватность и конфиденциальность'),
              _SettingsRow('Настройки стены', onTap: openPrivacy),
              _SettingsRow('Общая безопасность', onTap: openPrivacy),
              const SizedBox(height: 16),
              const _SectionTitle('Уведомления и звуки'),
              const _SettingsRow('Личные чаты'),
              const _SettingsRow('Групповые чаты'),
              const _SettingsRow('Уведомления со стены'),
              const SizedBox(height: 16),
              const _SectionTitle('Оформление и интерфейс'),
              const _SettingsRow('Тема'),
              const _SettingsRow('Размер шрифта'),
              const _SettingsRow('Фон чатов'),
              const SizedBox(height: 16),
              const _SectionTitle('Память и данные'),
              const _SettingsRow('Автозагрузка медиа'),
              const _SettingsRow('Использование памяти'),
              const SizedBox(height: 16),
              const _SectionTitle('Поддержка и информация'),
              const _SettingsRow('Помощь / FAQ'),
              const _SettingsRow('Связь с поддержкой'),
              _SettingsRow(
                'О приложении',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'А?',
                  applicationVersion: '1.0.0',
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Аккаунт'),
              _SettingsRow('Выйти', onTap: () => authRepository.signOut()),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
