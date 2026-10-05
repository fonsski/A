import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../auth/auth_repository.dart';
import '../auth/qr_login.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Телефон: сканирует QR на экране входа другого устройства и подтверждает
/// вход. Сканер подменяется в тестах через [scannerBuilder].
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.scannerBuilder});

  final Widget Function(ValueChanged<String> onCode)? scannerBuilder;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _manual = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _handle(String raw) async {
    if (_busy) return;
    if (parseQrPayload(raw) == null) {
      _toast('Это не QR-код входа в «А?»');
      return;
    }
    setState(() => _busy = true);
    try {
      final device = await authRepository.describeQrLogin(raw);
      if (!mounted) return;
      final ok = await _confirm(device);
      if (ok != true) return;
      await authRepository.approveQrLogin(raw);
      _toast('Вход подтверждён');
      if (mounted) Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String device) {
    final colors = context.colors;
    return showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Войти на другом устройстве?',
          style: TextStyle(color: colors.textPrimary, fontSize: 18),
        ),
        content: Text(
          '«$device» получит доступ к твоему аккаунту. '
          'Подтверждай, только если вход запросил ты сам.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(
              'Отмена',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              'Подтвердить',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultScanner(ValueChanged<String> onCode) => MobileScanner(
    controller: MobileScannerController(formats: const [BarcodeFormat.qrCode]),
    onDetect: (capture) {
      final raw = capture.barcodes.firstOrNull?.rawValue;
      if (raw != null) onCode(raw);
    },
    errorBuilder: (context, error) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Камера недоступна — вставь код ниже',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: AHeader(
                title: 'Вход по QR-коду',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild: Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
              child: Text(
                'Наведи камеру на QR-код на экране входа другого устройства',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: colors.card,
                    child: (widget.scannerBuilder ?? _defaultScanner)(_handle),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 12, 21, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: pillDecoration(colors.surface),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _manual,
                        onSubmitted: _handle,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Или вставь код',
                          hintStyle: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handle(_manual.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: pillDecoration(colors.accent),
                      child: _busy
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.bg,
                              ),
                            )
                          : Icon(Icons.check, color: colors.bg),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
