import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../auth/username.dart';
import '../../theme.dart';
import 'auth_widgets.dart';

/// Экран нового пароля: показывается после перехода по ссылке из письма
/// восстановления (пока [AuthRepository.recovering] == true).
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  String? _passwordError;
  String? _password2Error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _passwordError = validatePassword(_password.text);
      _password2Error = _password2.text != _password.text
          ? 'Пароли не совпадают'
          : null;
    });
    if (_passwordError != null || _password2Error != null) return;

    // После успеха AuthGate заменит этот экран, поэтому сообщение показываем
    // через ScaffoldMessenger приложения, взятый до await.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await authRepository.completeRecovery(_password.text);
      messenger.showSnackBar(const SnackBar(content: Text('Пароль изменён')));
    } on AuthFailure catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(21, 20, 21, 16),
          children: [
            const AuthTop(),
            Text(
              'Новый пароль',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Придумай пароль, которым будешь входить в аккаунт.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: kAuthToggleToForm),
            AuthField(
              label: 'Новый пароль',
              hint: 'пароль введи сюда',
              controller: _password,
              obscure: true,
              errorText: _passwordError,
            ),
            const SizedBox(height: kAuthFieldGap),
            AuthField(
              label: 'Повтори пароль',
              hint: 'еще раз пароль',
              controller: _password2,
              obscure: true,
              errorText: _password2Error,
            ),
            const SizedBox(height: kAuthFormToButton),
            AuthButton(
              label: 'Сохранить пароль',
              onPressed: _submit,
              busy: _busy,
            ),
            const SizedBox(height: 8),
            AuthLink(
              label: 'Отмена',
              onTap: _busy ? () {} : authRepository.cancelRecovery,
            ),
          ],
        ),
      ),
    );
  }
}
