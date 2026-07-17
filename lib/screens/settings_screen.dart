import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_repository.dart';
import '../main.dart';
import '../notifications/notification_service.dart';
import '../notifications/web_notifier_stub.dart'
    if (dart.library.js_interop) '../notifications/web_notifier_web.dart'
    as notifier;
import '../theme.dart';
import '../widgets/common.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyDm = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _notifyDm = prefs.getBool(kNotifyDmPref) ?? true);
      }
    });
  }

  Future<void> _toggleNotifyDm(bool value) async {
    setState(() => _notifyDm = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kNotifyDmPref, value);
    if (value && !await notifier.ensurePermission() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notifier.supported
                ? 'Браузер запретил уведомления — разреши их в настройках сайта'
                : 'Системные уведомления пока доступны только в веб-версии',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    void openPrivacy() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen()));
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
              const ASectionTitle('Приватность и конфиденциальность'),
              _SettingsRow('Настройки стены', onTap: openPrivacy),
              _SettingsRow('Общая безопасность', onTap: openPrivacy),
              const SizedBox(height: 16),
              const ASectionTitle('Уведомления и звуки'),
              _SettingsRow(
                'Личные чаты',
                trailing: Switch(
                  value: _notifyDm,
                  activeThumbColor: context.colors.accent,
                  onChanged: _toggleNotifyDm,
                ),
                onTap: () => _toggleNotifyDm(!_notifyDm),
              ),
              const _SettingsRow('Групповые чаты'),
              const _SettingsRow('Уведомления со стены'),
              const SizedBox(height: 16),
              const ASectionTitle('Оформление и интерфейс'),
              _SettingsRow(
                'Тема: ${themeMode.value == ThemeMode.dark ? 'тёмная' : 'светлая'}',
                onTap: () => themeMode.value = themeMode.value == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
              const _SettingsRow('Размер шрифта'),
              const _SettingsRow('Фон чатов'),
              const SizedBox(height: 16),
              const ASectionTitle('Память и данные'),
              const _SettingsRow('Автозагрузка медиа'),
              const _SettingsRow('Использование памяти'),
              const SizedBox(height: 16),
              const ASectionTitle('Поддержка и информация'),
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
              const ASectionTitle('Аккаунт'),
              _SettingsRow('Выйти', onTap: () => authRepository.signOut()),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.label, {this.onTap, this.trailing});

  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

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
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null)
                SizedBox(height: 28, child: FittedBox(child: trailing)),
            ],
          ),
        ),
      ),
    );
  }
}
