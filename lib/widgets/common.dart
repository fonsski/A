import 'package:flutter/material.dart';

import '../theme.dart';

const kPillRadius = 36.0;

/// Плашка-«пилюля» из макета: скруглённая на 36 с мягкой тенью.
BoxDecoration pillDecoration(
  Color color, {
  double radius = kPillRadius,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
    boxShadow: const [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  );
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
            child: circleChild ??
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

/// Круглый аватар из ассетов.
class AAvatar extends StatelessWidget {
  const AAvatar({super.key, this.size = 64, this.asset = 'assets/images/avatar.png'});

  final double size;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.cover),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(37, 8, 37, 12),
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
                      ? BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, -2),
                            ),
                          ],
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
