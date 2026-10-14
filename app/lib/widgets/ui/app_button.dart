import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, secondary, tonal, ghost, danger }

enum AppButtonSize { large, medium, small }

/// The app's one button. Primary actions are teal; [loading] swaps the
/// label for a spinner without changing the button's size.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.loading = false,
    this.expand = true,
    this.haptic = true,
    this.pill = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final bool expand;
  final bool haptic;

  /// Fully rounded ends instead of squircle corners.
  final bool pill;

  double get _height => switch (size) {
    AppButtonSize.large => 52,
    AppButtonSize.medium => 44,
    AppButtonSize.small => 36,
  };

  double get _fontSize => switch (size) {
    AppButtonSize.large => 16,
    AppButtonSize.medium => 15,
    AppButtonSize.small => 13,
  };

  (Color, Color, BorderSide?) _colors() => switch (variant) {
    AppButtonVariant.primary => (AppColors.primary, Colors.white, null),
    AppButtonVariant.secondary => (
      AppColors.surfaceLight,
      AppColors.textPrimary,
      const BorderSide(color: AppColors.borderStrong),
    ),
    AppButtonVariant.tonal => (AppColors.primarySoft, AppColors.primaryDeep, null),
    AppButtonVariant.ghost => (Colors.transparent, AppColors.primary, null),
    AppButtonVariant.danger => (AppColors.errorSoft, AppColors.error, null),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, side) = _colors();
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(
      size == AppButtonSize.small ? AppRadius.sm : AppRadius.md,
    );
    final textStyle = AppFonts.jakarta(
      fontSize: _fontSize,
      fontWeight: FontWeight.w700,
      color: fg,
    );
    final iconSize = size == AppButtonSize.small ? 16.0 : 20.0;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: fg),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 6),
          Icon(trailingIcon, size: iconSize, color: fg),
        ],
      ],
    );

    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Material(
          color: bg,
          shape: pill
              ? StadiumBorder(side: side ?? BorderSide.none)
              : RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: side ?? BorderSide.none,
                ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    if (haptic) HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            splashColor: fg.withValues(alpha: 0.12),
            highlightColor: fg.withValues(alpha: 0.06),
            child: SizedBox(
              height: _height,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size == AppButtonSize.small ? 12 : 20,
                ),
                child: Center(
                  // Hug the label when the button isn't stretched.
                  widthFactor: expand ? null : 1,
                  child: AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.fast),
                    child: loading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: iconSize,
                            height: iconSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: fg,
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('label'),
                            child: content,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final scaled = PressScale(enabled: enabled, child: button);
    return expand ? SizedBox(width: double.infinity, child: scaled) : scaled;
  }
}
