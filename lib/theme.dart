import 'package:flutter/material.dart';

/// Палитра из фрейма "colors" макета: слева светлая тема, справа тёмная.
class AColors extends ThemeExtension<AColors> {
  const AColors({
    required this.bg,
    required this.surface,
    required this.card,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.hint,
    required this.bubbleIn,
    required this.bubbleOut,
  });

  final Color bg; // фон экрана
  final Color surface; // белые плашки/пилюли
  final Color card; // подложка выделенного элемента
  final Color accent; // фирменный красный
  final Color textPrimary;
  final Color textSecondary;
  final Color hint;
  final Color bubbleIn; // входящее сообщение
  final Color bubbleOut; // исходящее сообщение

  static const light = AColors(
    bg: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFAFAFA),
    accent: Color(0xFFD9383A),
    textPrimary: Color(0xFF292929),
    textSecondary: Color(0xFF7D7D7D),
    hint: Color(0xFF969696),
    bubbleIn: Color(0xFFF5F5F5),
    bubbleOut: Color(0xFFFEECEE),
  );

  static const dark = AColors(
    bg: Color(0xFF141414),
    surface: Color(0xFF1E1E1E),
    card: Color(0xFF333333),
    accent: Color(0xFFFF6B6B),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF969696),
    hint: Color(0xFF7D7D7D),
    bubbleIn: Color(0xFF333333),
    bubbleOut: Color(0xFF3D1D20),
  );

  @override
  AColors copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? hint,
    Color? bubbleIn,
    Color? bubbleOut,
  }) {
    return AColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      hint: hint ?? this.hint,
      bubbleIn: bubbleIn ?? this.bubbleIn,
      bubbleOut: bubbleOut ?? this.bubbleOut,
    );
  }

  @override
  AColors lerp(AColors? other, double t) {
    if (other == null) return this;
    return AColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      bubbleIn: Color.lerp(bubbleIn, other.bubbleIn, t)!,
      bubbleOut: Color.lerp(bubbleOut, other.bubbleOut, t)!,
    );
  }
}

extension AColorsX on BuildContext {
  AColors get colors => Theme.of(this).extension<AColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final colors = brightness == Brightness.light ? AColors.light : AColors.dark;
  final base = ThemeData(
    brightness: brightness,
    fontFamily: 'RobotoFlex',
    scaffoldBackgroundColor: colors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
    ),
    useMaterial3: true,
  );
  return base.copyWith(extensions: [colors]);
}
