import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../auth/auth_repository.dart';
import '../../auth/qr_login.dart';
import '../../theme.dart';

/// Кадр «LogIn» с QR: белая плашка с кодом. Сама открывает QR-сессию, опрашивает
/// подтверждение и обновляет код, когда он протух. Когда телефон подтвердил
/// вход, репозиторий входит в аккаунт, а AuthGate переключает экран.
class QrLoginPanel extends StatefulWidget {
  const QrLoginPanel({
    super.key,
    this.pollInterval = const Duration(seconds: 2),
  });

  final Duration pollInterval;

  @override
  State<QrLoginPanel> createState() => _QrLoginPanelState();
}

class _QrLoginPanelState extends State<QrLoginPanel> {
  QrLoginSession? _session;
  String? _error;
  Timer? _timer;
  var _polling = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    setState(() {
      _session = null;
      _error = null;
    });
    try {
      final session = await authRepository.startQrLogin();
      if (!mounted) return;
      setState(() => _session = session);
      _timer = Timer.periodic(widget.pollInterval, (_) => _poll());
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _poll() async {
    final session = _session;
    if (session == null || _polling) return;
    if (session.expired) return _start(); // код протух — рисуем новый
    _polling = true;
    try {
      final result = await authRepository.pollQrLogin(session);
      if (!mounted) return;
      if (result == QrPoll.expired) {
        unawaited(_start());
      } else if (result == QrPoll.signedIn) {
        _timer?.cancel();
      }
    } on AuthFailure catch (e) {
      _timer?.cancel();
      if (mounted) setState(() => _error = e.message);
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final session = _session;
    return Column(
      children: [
        Container(
          width: 216,
          height: 216,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: session != null
              ? QrImageView(
                  data: session.payload,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                )
              : Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                            TextButton(
                              onPressed: _start,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                ),
        ),
        if (session != null)
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: session.payload));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Код скопирован')));
              }
            },
            child: Text(
              'Скопировать код',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          )
        else
          const SizedBox(height: 48),
      ],
    );
  }
}
