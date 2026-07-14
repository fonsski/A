import 'package:flutter/material.dart';

import '../screens/auth/auth_flow.dart';
import '../screens/auth/pick_username_screen.dart';
import '../screens/home_shell.dart';
import 'auth_repository.dart';

/// Корневой роутер по состоянию сессии:
/// нет сессии → вход; нет ника → онбординг; иначе → приложение.
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
        return const HomeShell();
      },
    );
  }
}
