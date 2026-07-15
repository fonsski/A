import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme.dart';

const kPillRadius = 36.0;

/// Плашка-«пилюля» из макета: скруглённая, с ВНУТРЕННЕЙ тенью
/// (в Figma все эффекты — inset box-shadow, обычно 0 2 4 rgba(0,0,0,.1)).
Decoration pillDecoration(
  Color color, {
  double radius = kPillRadius,
  Color? borderColor,
  Offset inset = const Offset(0, 2),
}) {
  return InsetPillDecoration(
    color: color,
    radius: radius,
    borderColor: borderColor,
    insetOffset: inset,
  );
}

/// Скруглённый прямоугольник с inset-тенью — аналог CSS
/// `box-shadow: inset dx dy 4px rgba(0,0,0,0.1)`.
class InsetPillDecoration extends Decoration {
  const InsetPillDecoration({
    required this.color,
    required this.radius,
    this.borderColor,
    this.insetOffset = const Offset(0, 2),
    this.shadowColor = const Color(0x1A000000),
    this.blurSigma = 2,
  });

  final Color color;
  final double radius;
  final Color? borderColor;
  final Offset insetOffset;
  final Color shadowColor;
  final double blurSigma;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _InsetPillPainter(this);
}

class _InsetPillPainter extends BoxPainter {
  _InsetPillPainter(this.decoration);

  final InsetPillDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(decoration.radius),
    );

    canvas.drawRRect(rrect, Paint()..color = decoration.color);

    // Inset-тень: внутри пилюли рисуем размытую «раму» — область снаружи
    // той же пилюли, сдвинутой на offset тени.
    canvas.save();
    canvas.clipRRect(rrect);
    final shadowPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(24))
      ..addRRect(rrect.shift(decoration.insetOffset));
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = decoration.shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, decoration.blurSigma),
    );
    canvas.restore();

    final borderColor = decoration.borderColor;
    if (borderColor != null) {
      canvas.drawRRect(
        rrect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = borderColor,
      );
    }
  }
}

/// Красная шапка экрана: длинная пилюля с заголовком и круглая кнопка справа.
class AHeader extends StatelessWidget {
  const AHeader({
    super.key,
    required this.title,
    this.onTapCircle,
    this.circleChild,
  });

  final String title;
  final VoidCallback? onTapCircle;
  final Widget? circleChild;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            alignment: Alignment.centerLeft,
            decoration: pillDecoration(colors.accent),
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.bg,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTapCircle,
          child: Container(
            width: 36,
            height: 36,
            decoration: pillDecoration(colors.accent),
            child:
                circleChild ??
                Icon(Icons.chevron_right, color: colors.bg, size: 20),
          ),
        ),
      ],
    );
  }
}

/// Белая пилюля-поле (поиск, «Новый пост?» и т.п.).
class APill extends StatelessWidget {
  const APill({
    super.key,
    required this.child,
    this.color,
    this.height = 36,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 28),
    this.borderColor,
  });

  final Widget child;
  final Color? color;
  final double height;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: padding,
        alignment: Alignment.centerLeft,
        decoration: pillDecoration(
          color ?? context.colors.surface,
          borderColor: borderColor,
        ),
        child: child,
      ),
    );
  }
}

/// Провайдер картинки из URL любого вида:
/// http(s), data-URI (мок) или `asset:путь` (демо-данные).
ImageProvider imageProviderFor(String url) {
  if (url.startsWith('data:')) {
    return MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
  }
  if (url.startsWith('asset:')) {
    return AssetImage(url.substring('asset:'.length));
  }
  return NetworkImage(url);
}

/// Круглый аватар: URL из Storage, data-URI (мок) или ассет-заглушка.
class AAvatar extends StatelessWidget {
  const AAvatar({
    super.key,
    this.size = 64,
    this.url,
    this.asset = 'assets/images/avatar.png',
  });

  final double size;
  final String? url;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final value = url;
    return ClipOval(
      child: Image(
        image: value == null || value.isEmpty
            ? AssetImage(asset)
            : imageProviderFor(value),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
      ),
    );
  }
}

/// Нижняя навигация: белая пилюля с четырьмя иконками.
class ABottomNav extends StatelessWidget {
  const ABottomNav({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _icons = [
    'assets/images/nav_chats.png',
    'assets/images/nav_wall.png',
    'assets/images/nav_settings.png',
    'assets/images/nav_profile.png',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Как и стенка: на широких экранах пилюля занимает центральную половину.
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 700 ? width * 0.25 : 37.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 8, side, 12),
      child: Container(
        height: 62,
        decoration: pillDecoration(colors.surface),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < _icons.length; i++)
              GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 68,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: i == index
                      ? pillDecoration(
                          colors.card,
                          radius: 32,
                          inset: const Offset(0, -2),
                        )
                      : null,
                  child: Image.asset(_icons[i], width: 30, height: 30),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
