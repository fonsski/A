import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../auth/username.dart';
import 'auth_widgets.dart';

/// Экран "Sing up": регистрация по почте.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    required this.onLoginTap,
    required this.onRegistered,
  });

  final VoidCallback onLoginTap;
  final ValueChanged<String> onRegistered;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _password2Error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = validateEmail(_email.text);
      _passwordError = validatePassword(_password.text);
      _password2Error =
          _password2.text != _password.text ? 'Пароли не совпадают' : null;
    });
    if (_emailError != null ||
        _passwordError != null ||
        _password2Error != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await authRepository.signUp(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      widget.onRegistered(_email.text.trim());
    } on AuthFailure catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
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
              signUpSelected: true,
              onChanged: (signUp) {
                if (!signUp) widget.onLoginTap();
              },
            ),
            const SizedBox(height: 32),
            AuthField(
              label: 'Email',
              hint: 'gnida@tvar.ru',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Пароль',
              hint: 'пароль введи сюда',
              controller: _password,
              obscure: true,
              errorText: _passwordError,
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Повтори пароль',
              hint: 'еще раз пароль',
              controller: _password2,
              obscure: true,
              errorText: _password2Error,
            ),
            const SizedBox(height: 32),
            AuthButton(
              label: 'Зарегистрироваться',
              onPressed: _submit,
              busy: _busy,
            ),
            const SizedBox(height: 8),
            AuthLink(label: 'Уже есть аккаунт?', onTap: widget.onLoginTap),
          ],
        ),
      ),
    );
  }
}
