import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_repository.dart';
import '../config.dart';
import '../main.dart';
import '../notifications/notification_service.dart';
import '../notifications/web_notifier_stub.dart'
    if (dart.library.js_interop) '../notifications/web_notifier_web.dart'
    as notifier;
import '../settings/app_settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_security_screen.dart';
import 'faq_screen.dart';
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
    appSettings.addListener(_onSettingsChanged);
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _notifyDm = prefs.getBool(kNotifyDmPref) ?? true);
      }
    });
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  /// Лист выбора одного варианта: галочка у текущего, тап — выбрать и закрыть.
  Future<void> _pickOption({
    required String title,
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onSelect,
    Widget? Function(int index)? leading,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ASectionTitle(title),
              ),
            ),
            // Прокручиваемый список: на невысоком окне варианты не должны
            // вылезать за границы листа.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (var i = 0; i < labels.length; i++)
                    ListTile(
                      leading: leading?.call(i),
                      title: Text(
                        labels[i],
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      trailing: i == selected
                          ? Icon(Icons.check, color: colors.accent)
                          : null,
                      onTap: () {
                        onSelect(i);
                        Navigator.of(sheet).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFontSize() => _pickOption(
    title: 'Размер шрифта в чатах',
    labels: [for (final o in kFontSizeOptions) o.label],
    selected: appSettings.fontSizeIndex,
    onSelect: appSettings.setFontSizeIndex,
  );

  Future<void> _pickChatBackground() {
    final brightness = Theme.of(context).brightness;
    final colors = context.colors;
    return _pickOption(
      title: 'Фон чатов',
      labels: [for (final o in kChatBackgrounds) o.label],
      selected: appSettings.chatBackgroundIndex,
      onSelect: appSettings.setChatBackgroundIndex,
      leading: (i) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: kChatBackgrounds[i].colorFor(brightness) ?? colors.bg,
          shape: BoxShape.circle,
          border: Border.all(color: colors.hint),
        ),
      ),
    );
  }

  Future<void> _showMemoryUsage() {
    final colors = context.colors;
    return showDialog<void>(
      context: context,
      builder: (dialog) {
        final cache = PaintingBinding.instance.imageCache;
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            'Использование памяти',
            style: TextStyle(color: colors.textPrimary, fontSize: 18),
          ),
          content: Text(
            'Кэш изображений: ${formatBytes(cache.currentSizeBytes)} '
            '(${cache.currentSize} шт.)',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(),
              child: Text('Закрыть', style: TextStyle(color: colors.hint)),
            ),
            TextButton(
              onPressed: () {
                cache
                  ..clear()
                  ..clearLiveImages();
                Navigator.of(dialog).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Кэш очищен')));
              },
              child: Text('Очистить', style: TextStyle(color: colors.accent)),
            ),
          ],
        );
      },
    );
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
              _SettingsRow(
                'Размер шрифта',
                trailing: _ValueLabel(
                  kFontSizeOptions[appSettings.fontSizeIndex].label,
                ),
                onTap: _pickFontSize,
              ),
              _SettingsRow(
                'Фон чатов',
                trailing: _ValueLabel(
                  kChatBackgrounds[appSettings.chatBackgroundIndex].label,
                ),
                onTap: _pickChatBackground,
              ),
              const SizedBox(height: 16),
              const ASectionTitle('Память и данные'),
              _SettingsRow(
                'Автозагрузка медиа',
                trailing: Switch(
                  value: appSettings.autoloadMedia,
                  activeThumbColor: context.colors.accent,
                  onChanged: appSettings.setAutoloadMedia,
                ),
                onTap: () =>
                    appSettings.setAutoloadMedia(!appSettings.autoloadMedia),
              ),
              _SettingsRow('Использование памяти', onTap: _showMemoryUsage),
              const SizedBox(height: 16),
              const ASectionTitle('Поддержка и информация'),
              _SettingsRow(
                'Помощь / FAQ',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
              ),
              const _SettingsRow('Связь с поддержкой'),
              _SettingsRow(
                'О приложении',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'А?',
                  applicationVersion: AppConfig.version,
                ),
              ),
              const SizedBox(height: 16),
              const ASectionTitle('Аккаунт и безопасность'),
              _SettingsRow(
                'Безопасность и вход',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountSecurityScreen(),
                  ),
                ),
              ),
              _SettingsRow('Выйти', onTap: () => authRepository.signOut()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Размер в человекочитаемом виде: «512 Б», «1.5 КБ», «3.2 МБ».
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}

/// Текущее значение настройки справа в строке.
class _ValueLabel extends StatelessWidget {
  const _ValueLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
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
