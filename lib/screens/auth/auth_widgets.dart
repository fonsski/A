import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

/// Логотип «А?» в шапке экранов входа/регистрации.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/images/logo.png', width: 48, height: 48),
      ),
    );
  }
}

/// Переключатель «Войти / Вступить» из макета.
class AuthToggle extends StatelessWidget {
  const AuthToggle({
    super.key,
    required this.signUpSelected,
    required this.onChanged,
  });

  final bool signUpSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget segment(String label, bool isSignUp) {
      final selected = isSignUp == signUpSelected;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(isSignUp),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: selected
                ? pillDecoration(colors.card, radius: 24)
                : null,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: pillDecoration(
        colors.surface,
        radius: 24,
        inset: const Offset(0, -2),
      ),
      child: Row(
        children: [segment('Войти', false), segment('Вступить', true)],
      ),
    );
  }
}

/// Подпись + белое поле-пилюля (r24), как в макете.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.errorText,
    this.keyboardType,
    this.onChanged,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: pillDecoration(
            colors.surface,
            radius: 24,
            inset: const Offset(0, -2),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              ?suffix,
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: TextStyle(color: colors.accent, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

/// Красная кнопка действия (r24) с индикатором загрузки.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: busy ? null : onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.bg,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: colors.bg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Центрированная текстовая ссылка («Уже есть аккаунт?» и т.п.).
class AuthLink extends StatelessWidget {
  const AuthLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
        ),
      ),
    );
  }
}

void showAuthError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
}
