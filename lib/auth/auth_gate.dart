import 'package:flutter/material.dart';

import '../screens/auth/auth_flow.dart';
import '../screens/auth/pick_username_screen.dart';
import '../screens/auth/pin_lock_screen.dart';
import '../screens/home_shell.dart';
import 'auth_repository.dart';
import 'pin_lock.dart';

/// Корневой роутер по состоянию сессии:
/// нет сессии → вход; нет ника → онбординг; код установлен и заперто →
/// PIN-замок; иначе → приложение.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSnapshot?>(
      stream: authRepository.snapshots,
      initialData: authRepository.current,
      builder: (context, snapshot) {
        final auth = snapshot.data;
        if (auth == null) return const AuthFlow();
        if (auth.needsUsername) return const PickUsernameScreen();
        return ValueListenableBuilder<bool>(
          valueListenable: pinLock.locked,
          builder: (context, locked, _) =>
              locked ? const PinLockScreen() : const HomeShell(),
        );
      },
    );
  }
}
