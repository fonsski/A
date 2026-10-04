import 'package:flutter/material.dart';

import '../../theme.dart';

/// Ширина, с которой вход оформляется как на десктопном кадре макета.
const kAuthDesktopBreakpoint = 900.0;

const _backdrop = Color(0xFF292929);
const _cardColor = Color(0xFF1F1F1F);
const _brandRed = Color(0xFFD9383A);

/// На широком экране (кадр «Desktop - 1») формы входа/регистрации живут в
/// тёмной карточке поверх фона с красными линиями; на узком — как есть.
class AuthDesktopFrame extends StatelessWidget {
  const AuthDesktopFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < kAuthDesktopBreakpoint) return child;

    // Палитра десктопных карточек: поля светлее подложки, выбранный
    // сегмент переключателя темнее дорожки. `bg` здесь — цвет текста на
    // красных кнопках (в макете белый); фон Scaffold ниже прозрачный.
    const colors = AColors(
      bg: Color(0xFFF8F9FA),
      surface: Color(0xFF2A2A2A),
      card: Color(0xFF1C1C1C),
      accent: _brandRed,
      textPrimary: Color(0xFFF5F5F5),
      textSecondary: Color(0xFF8A8A8A),
      hint: Color(0xFF7D7D7D),
      bubbleIn: Color(0xFF333333),
      bubbleOut: Color(0xFF3D1D20),
    );
    final theme = buildTheme(Brightness.dark).copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      extensions: const [colors],
    );

    return Scaffold(
      backgroundColor: _backdrop,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _LinesPainter())),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: ColoredBox(
                  color: _cardColor,
                  child: Theme(data: theme, child: child),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Text(
              'A.Messenger © 202*',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Красные контурные линии и «пилюли» фона из кадра «Desktop - 1».
/// Координаты заданы для 1600×900 и масштабируются под окно.
class _LinesPainter extends CustomPainter {
  const _LinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 1600;
    final sy = size.height / 900;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final paint = Paint()
      ..color = _brandRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Левая диагональ и горизонталь, уходящая к нижней «петле».
    canvas.drawLine(p(0, 900), p(205, 668), paint);
    canvas.drawLine(p(200, 675), p(800, 675), paint);
    final lowerLoop = Path()
      ..moveTo(p(800, 665).dx, p(800, 665).dy)
      ..arcToPoint(
        p(900, 665),
        radius: Radius.elliptical(50 * sx, 60 * sy),
        clockwise: false,
      );
    canvas.drawPath(lowerLoop, paint);

    // Верхняя «петля» над центральной карточкой.
    canvas.drawLine(p(560, 270), p(715, 90), paint);
    final upperLoop = Path()
      ..moveTo(p(715, 90).dx, p(715, 90).dy)
      ..arcToPoint(p(800, 120), radius: Radius.elliptical(45 * sx, 40 * sy))
      ..lineTo(p(800, 235).dx, p(800, 235).dy);
    canvas.drawPath(upperLoop, paint);

    // Правая часть: петли над и под карточкой и длинная диагональ.
    canvas.drawLine(p(1000, 450), p(1035, 360), paint);
    final rightTop = Path()
      ..moveTo(p(1097, 235).dx, p(1097, 235).dy)
      ..lineTo(p(1115, 190).dx, p(1115, 190).dy)
      ..arcToPoint(p(1200, 220), radius: Radius.elliptical(45 * sx, 45 * sy))
      ..lineTo(p(1200, 235).dx, p(1200, 235).dy);
    canvas.drawPath(rightTop, paint);
    final rightBottom = Path()
      ..moveTo(p(1200, 665).dx, p(1200, 665).dy)
      ..arcToPoint(
        p(1300, 665),
        radius: Radius.elliptical(50 * sx, 60 * sy),
        clockwise: false,
      );
    canvas.drawPath(rightBottom, paint);
    canvas.drawLine(p(1440, 360), p(1600, 0), paint);
  }

  @override
  bool shouldRepaint(_LinesPainter oldDelegate) => false;
}
