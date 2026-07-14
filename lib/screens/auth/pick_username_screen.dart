import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/auth_repository.dart';
import '../../auth/username.dart';
import '../../theme.dart';
import 'auth_widgets.dart';

/// Шаг онбординга после первого входа: выбор @ника и имени.
class PickUsernameScreen extends StatefulWidget {
  const PickUsernameScreen({super.key});

  @override
  State<PickUsernameScreen> createState() => _PickUsernameScreenState();
}

enum _Availability { unknown, checking, free, taken }

class _PickUsernameScreenState extends State<PickUsernameScreen> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  String? _usernameError;
  _Availability _availability = _Availability.unknown;
  Timer? _debounce;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String raw) {
    _debounce?.cancel();
    final error = validateUsernameFormat(raw);
    setState(() {
      _usernameError = error;
      _availability = _Availability.unknown;
    });
    if (error != null) return;
    // Живая проверка занятости с debounce, финальная гарантия — на сервере.
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _availability = _Availability.checking);
      final free =
          await authRepository.isUsernameAvailable(raw.trim().toLowerCase());
      if (!mounted || _username.text != raw) return;
      setState(() =>
          _availability = free ? _Availability.free : _Availability.taken);
    });
  }

  Future<void> _submit() async {
    final error = validateUsernameFormat(_username.text);
    setState(() => _usernameError = error);
    if (error != null) return;
    if (_availability == _Availability.taken) return;

    setState(() => _busy = true);
    try {
      await authRepository.claimUsername(
        username: _username.text,
        displayName: _displayName.text,
      );
      // AuthGate переключит на главный экран сам.
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _availability = _Availability.taken);
        showAuthError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _availabilityMark() {
    final colors = context.colors;
    return switch (_availability) {
      _Availability.checking => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      _Availability.free => Icon(Icons.check, color: Colors.green, size: 20),
      _Availability.taken => Icon(Icons.close, color: colors.accent, size: 20),
      _Availability.unknown => const SizedBox.shrink(),
    };
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
              'Как тебя называть?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),
            AuthField(
              label: 'Имя пользователя (@ник)',
              hint: 'de.panda',
              controller: _username,
              errorText: _availability == _Availability.taken
                  ? 'Этот ник уже занят'
                  : _usernameError,
              onChanged: _onUsernameChanged,
              suffix: _availabilityMark(),
            ),
            const SizedBox(height: 20),
            AuthField(
              label: 'Имя (можно потом)',
              hint: 'Denis Panda',
              controller: _displayName,
            ),
            const SizedBox(height: 32),
            AuthButton(label: 'Погнали!', onPressed: _submit, busy: _busy),
            const SizedBox(height: 8),
            AuthLink(
              label: 'Выйти из аккаунта',
              onTap: () => authRepository.signOut(),
            ),
          ],
        ),
      ),
    );
  }
}
