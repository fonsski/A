import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../theme.dart';
import 'auth_widgets.dart';

/// После регистрации: просим подтвердить почту и ведём на вход.
class ConfirmEmailScreen extends StatelessWidget {
  const ConfirmEmailScreen({
    super.key,
    required this.email,
    required this.onGoToLogin,
  });

  final String email;
  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(21, 20, 21, 16),
          children: [
            const SizedBox(height: 32),
            const AuthLogo(),
            const SizedBox(height: 48),
            Text(
              'Проверь почту',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Мы отправили письмо на\n$email\n\n'
              'Перейди по ссылке из письма,\nа потом войди со своим паролем.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            AuthButton(
              label: 'Я подтвердил — войти',
              onPressed: onGoToLogin,
            ),
            const SizedBox(height: 8),
            AuthLink(
              label: 'Отправить письмо ещё раз',
              onTap: () async {
                await authRepository.resendConfirmation(email);
                if (context.mounted) {
                  showAuthError(context, 'Письмо отправлено ещё раз');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
