import 'package:flutter/material.dart';

import 'confirm_email_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

enum _AuthPage { login, signUp, confirmEmail }

/// Переключение вход/регистрация/подтверждение почты внутри одного роута —
/// AuthGate остаётся корнем и сам среагирует на появление сессии.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  _AuthPage _page = _AuthPage.login;
  String _pendingEmail = '';

  @override
  Widget build(BuildContext context) {
    return switch (_page) {
      _AuthPage.login => LoginScreen(
        onSignUpTap: () => setState(() => _page = _AuthPage.signUp),
      ),
      _AuthPage.signUp => SignUpScreen(
        onLoginTap: () => setState(() => _page = _AuthPage.login),
        onRegistered: (email) => setState(() {
          _pendingEmail = email;
          _page = _AuthPage.confirmEmail;
        }),
      ),
      _AuthPage.confirmEmail => ConfirmEmailScreen(
        email: _pendingEmail,
        onGoToLogin: () => setState(() => _page = _AuthPage.login),
      ),
    };
  }
}
