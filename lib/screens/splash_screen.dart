import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_gate.dart';

/// Экран "Log": красный фон и логотип «А?» по центру.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9383A),
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Image.asset('assets/images/logo.png', width: 170, height: 170),
        ),
      ),
    );
  }
}
