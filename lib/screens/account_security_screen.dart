import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../auth/username.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Экран «Безопасность и вход» (кадр «Вход и бехопсность» в макете):
/// настройки аккаунта (почта) и безопасность (пароль).
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _changeEmail(BuildContext context) async {
    final input = await _askFields(
      context,
      title: 'Новая почта',
      fields: const [_DialogField('Новая почта', TextInputType.emailAddress)],
    );
    if (input == null || !context.mounted) return;
    final error = validateEmail(input.first);
    if (error != null) return _toast(context, error);
    try {
      await authRepository.changeEmail(input.first);
      if (context.mounted) {
        _toast(
          context,
          'Письмо со ссылкой отправлено на ${input.first.trim()} — '
          'почта сменится после подтверждения',
        );
      }
    } on AuthFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final input = await _askFields(
      context,
      title: 'Смена пароля',
      fields: const [
        _DialogField('Текущий пароль', null, obscure: true),
        _DialogField('Новый пароль', null, obscure: true),
        _DialogField('Повтори новый пароль', null, obscure: true),
      ],
    );
    if (input == null || !context.mounted) return;
    final error =
        validatePassword(input[1]) ??
        (input[1] != input[2] ? 'Пароли не совпадают' : null);
    if (error != null) return _toast(context, error);
    try {
      await authRepository.changePassword(current: input[0], next: input[1]);
      if (context.mounted) _toast(context, 'Пароль изменён');
    } on AuthFailure catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

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
                title: 'Безопасность и вход',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild: Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            Expanded(
              child: StreamBuilder<AuthSnapshot?>(
                stream: authRepository.snapshots,
                initialData: authRepository.current,
                builder: (context, snapshot) {
                  final email = snapshot.data?.email ?? '';
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    children: [
                      const ASectionTitle('Настройки аккаунта'),
                      _LabeledRow(
                        label: 'Электронная почта',
                        value: maskEmail(email),
                        action: 'Изменить',
                        onTap: () => _changeEmail(context),
                      ),
                      const SizedBox(height: 16),
                      const ASectionTitle('Безопасность и вход'),
                      _LabeledRow(
                        label: 'Пароль',
                        value: '••••••••',
                        action: 'Изменить',
                        onTap: () => _changePassword(context),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Подпись + белая пилюля со значением и кнопкой-контуром справа.
class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.label,
    required this.value,
    required this.action,
    required this.onTap,
  });

  final String label;
  final String value;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 8),
          child: Text(
            label,
            style: TextStyle(color: colors.textPrimary, fontSize: 16),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                decoration: pillDecoration(colors.surface),
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 36,
                width: 116,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kPillRadius),
                  border: Border.all(color: colors.accent),
                ),
                child: Text(
                  action,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogField {
  const _DialogField(this.hint, this.keyboardType, {this.obscure = false});

  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
}

/// Диалог с несколькими полями; null — отмена, иначе значения по порядку.
Future<List<String>?> _askFields(
  BuildContext context, {
  required String title,
  required List<_DialogField> fields,
}) {
  final colors = context.colors;
  final controllers = [for (final _ in fields) TextEditingController()];
  return showDialog<List<String>>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        title,
        style: TextStyle(color: colors.textPrimary, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < fields.length; i++)
            TextField(
              controller: controllers[i],
              autofocus: i == 0,
              obscureText: fields[i].obscure,
              keyboardType: fields[i].keyboardType,
              decoration: InputDecoration(hintText: fields[i].hint),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text('Отмена', style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialog).pop([for (final c in controllers) c.text]),
          child: Text(
            'Сохранить',
            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
