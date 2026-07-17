import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../auth/username.dart';
import 'auth_widgets.dart';

/// Экран "LogIn": вход по почте или @нику.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignUpTap});

  final VoidCallback onSignUpTap;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _identifierError;
  String? _passwordError;
  bool _busy = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _identifierError = _identifier.text.trim().isEmpty
          ? 'Введи почту или ник'
          : null;
      _passwordError = _password.text.isEmpty ? 'Введи пароль' : null;
    });
    if (_identifierError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      await authRepository.signIn(
        identifier: _identifier.text,
        password: _password.text,
      );
      // Дальше AuthGate сам покажет выбор ника или главный экран.
    } on AuthFailure catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final controller = TextEditingController(text: _identifier.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановить доступ'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Почта аккаунта'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    if (validateEmail(email) != null) {
      showAuthError(context, 'Это не похоже на почту');
      return;
    }
    await authRepository.requestPasswordReset(email);
    if (mounted) {
      showAuthError(context, 'Если такая почта есть — письмо уже в пути');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(21, 20, 21, 16),
          children: [
            const SizedBox(height: 32),
            const AuthLogo(),
            const SizedBox(height: 48),
            AuthToggle(
              signUpSelected: false,
              onChanged: (signUp) {
                if (signUp) widget.onSignUpTap();
              },
            ),
            const SizedBox(height: 32),
            AuthField(
              label: 'Email или имя пользователя',
              hint: '@gnida or gnida@tvar.ru',
              controller: _identifier,
              keyboardType: TextInputType.emailAddress,
              errorText: _identifierError,
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Пароль',
              hint: 'пароль введи сюда',
              controller: _password,
              obscure: true,
              errorText: _passwordError,
            ),
            const SizedBox(height: 32),
            AuthButton(label: 'Войти!', onPressed: _submit, busy: _busy),
            const SizedBox(height: 8),
            AuthLink(label: 'Восcтановить доступ?', onTap: _resetPassword),
          ],
        ),
      ),
    );
  }
}
