import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/auth/auth_desktop_frame.dart';
import '../screens/auth/auth_flow.dart';
import '../screens/auth/new_password_screen.dart';
import '../screens/auth/pick_username_screen.dart';
import '../screens/auth/pin_lock_screen.dart';
import '../screens/home_shell.dart';
import 'auth_repository.dart';
import 'pin_lock.dart';

/// Корневой роутер по состоянию сессии:
/// нет сессии → вход; нет ника → онбординг; код установлен и заперто →
/// PIN-замок; иначе → приложение.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<String>? _linkErrors;

  @override
  void initState() {
    super.initState();
    // Битая ссылка из письма: без сообщения пользователь не понимает, что
    // произошло (ссылка одноразовая, второй клик по ней уже не сработает).
    _linkErrors = authRepository.linkErrors.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    _linkErrors?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ссылка восстановления из письма важнее любого другого состояния.
    return ValueListenableBuilder<bool>(
      valueListenable: authRepository.recovering,
      builder: (context, recovering, _) {
        if (recovering) {
          return const AuthDesktopFrame(child: NewPasswordScreen());
        }
        return _sessionGate();
      },
    );
  }

  Widget _sessionGate() {
    return StreamBuilder<AuthSnapshot?>(
      stream: authRepository.snapshots,
      initialData: authRepository.current,
      builder: (context, snapshot) {
        final auth = snapshot.data;
        if (auth == null) return const AuthDesktopFrame(child: AuthFlow());
        if (auth.needsUsername) {
          return const AuthDesktopFrame(child: PickUsernameScreen());
        }
        return ValueListenableBuilder<bool>(
          valueListenable: pinLock.locked,
          builder: (context, locked, _) =>
              locked ? const PinLockScreen() : const HomeShell(),
        );
      },
    );
  }
}
