import 'package:flutter/material.dart';

import 'tokens.dart';

/// Set to false to hide the "→ Demo: …" buttons from the Figma wireframe.
const bool kDemoMode = true;

const kPagePadding = EdgeInsets.symmetric(horizontal: 24);

void showMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message.toString())));
}

enum AppButtonStyle { primary, slate, danger, outline }

/// 48px, radius-12 button used on every screen.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (Color bg, Color fg, BorderSide side) = switch (style) {
      AppButtonStyle.primary => (AppColors.primary, Colors.white, BorderSide.none),
      AppButtonStyle.slate => (AppColors.slate, Colors.white, BorderSide.none),
      AppButtonStyle.danger => (AppColors.red, Colors.white, BorderSide.none),
      AppButtonStyle.outline =>
        (Colors.white, AppColors.primary, const BorderSide(color: AppColors.slate, width: 1.5)),
    };
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: style == AppButtonStyle.outline ? Colors.white : AppColors.disabled,
          disabledForegroundColor: style == AppButtonStyle.outline ? AppColors.disabled : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: side),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: style == AppButtonStyle.outline ? fg : Colors.white),
              )
            : Text(label,
                style: AppText.button.copyWith(
                    color: enabled ? fg : (style == AppButtonStyle.outline ? AppColors.disabled : Colors.white))),
      ),
    );
  }
}

/// Label + 44px filled field, with the red "duplicate ID" error state.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    OutlineInputBorder border(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 5),
        SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: AppText.input,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.hint,
              filled: true,
              fillColor: hasError ? AppColors.redFieldFill : AppColors.fieldFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              enabledBorder: hasError ? border(AppColors.red, 1.5) : border(AppColors.border, 1),
              focusedBorder: hasError ? border(AppColors.red, 1.5) : border(AppColors.primary, 1.5),
              suffixIcon: hasError
                  ? const Padding(padding: EdgeInsets.only(right: 14), child: ErrorDot())
                  : suffix,
              suffixIconConstraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(errorText!, style: AppText.inter(11, FontWeight.w400, AppColors.red)),
        ],
      ],
    );
  }
}

/// Small red "!" circle shown inside an invalid field.
class ErrorDot extends StatelessWidget {
  const ErrorDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
        child: Text('!', style: AppText.inter(11, FontWeight.w700, Colors.white)),
      );
}

/// Soft coloured circle with an icon in the middle (status illustrations).
class IconCircle extends StatelessWidget {
  const IconCircle({super.key, required this.size, required this.color, this.child});

  final double size;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: child,
      );
}

/// The rounded-square "face frame" drawn inside the biometric circles.
class FaceFrame extends StatelessWidget {
  const FaceFrame({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 3),
        ),
      );
}

/// 36px round back button (top-left of state screens).
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.fieldFill,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.arrow_back, size: 18, color: AppColors.textPrimary),
          ),
        ),
      );
}

/// Pill used for "2 of 3 tries left" / "Unlocks in 14:32".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.background, required this.style, this.height = 28, this.border});

  final String text;
  final Color background;
  final TextStyle style;
  final double height;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        width: 180,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(height / 2),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Text(text, style: style),
      );
}

/// "→ Demo: …" helper buttons from the wireframe (only when [kDemoMode]).
class DemoLink extends StatelessWidget {
  const DemoLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!kDemoMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Material(
        color: AppColors.demoFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 28,
            width: double.infinity,
            child: Center(child: Text('→ Demo: $label', style: AppText.inter(11, FontWeight.w500, AppColors.primary))),
          ),
        ),
      ),
    );
  }
}

/// Centred layout used by the state screens (failed, locked, offline…).
class StateScaffold extends StatelessWidget {
  const StateScaffold({super.key, required this.children, this.onBack, this.footer = const []});

  final List<Widget> children;
  final VoidCallback? onBack;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: kPagePadding,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: onBack == null ? const SizedBox(height: 36) : BackCircleButton(onPressed: onBack!),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: children),
                ),
              ),
              ...footer,
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
