import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../auth/pin_lock.dart';
import '../../theme.dart';
import 'auth_widgets.dart';

/// Замок приложения: спрашивает код перед показом контента.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (pinLock.unlock(_controller.text.trim())) return; // AuthGate отопрёт
    setState(() => _error = 'Неверный код');
    _controller.clear();
  }

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
              'Код для входа',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            AuthField(
              label: 'Код',
              hint: '••••',
              controller: _controller,
              obscure: true,
              keyboardType: TextInputType.number,
              errorText: _error,
            ),
            const SizedBox(height: 32),
            AuthButton(label: 'Открыть', onPressed: _submit),
            const SizedBox(height: 8),
            AuthLink(
              label: 'Выйти из аккаунта',
              onTap: () async {
                // Забыл код — выход сбрасывает и сессию, и замок.
                await pinLock.clear();
                await authRepository.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
