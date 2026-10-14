import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';

enum SnackTone { neutral, success, error, info }

/// Short floating message at the bottom. Replaces the current one and goes
/// away after [duration], even with an action button (Undo, Retry, …).
void showAppSnack(
  BuildContext context,
  String message, {
  SnackTone tone = SnackTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final (IconData? icon, Color iconColor) = switch (tone) {
    SnackTone.success => (
      HugeIcons.strokeRoundedCheckmarkCircle02,
      const Color(0xFF9EE3B0),
    ),
    SnackTone.error => (HugeIcons.strokeRoundedAlert02, const Color(0xFFFFB4AB)),
    SnackTone.info => (
      HugeIcons.strokeRoundedInformationCircle,
      const Color(0xFFA9CBF0),
    ),
    SnackTone.neutral => (null, Colors.white),
  };
  if (tone == SnackTone.error) HapticFeedback.mediumImpact();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        // Flutter keeps a snack bar with an action until it's tapped unless
        // told otherwise; ours always time out.
        persist: false,
        content: Row(
          children: [
            if (icon != null) ...[
              HugeIcon(icon: icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}

/// Confirmation dialog. Resolves to true only when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: AppMotion.of(context, AppMotion.base),
    pageBuilder: (dialogContext, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: destructive
                            ? AppColors.errorSoft
                            : AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: icon,
                          size: 24,
                          color: destructive
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    title,
                    style: AppFonts.jakarta(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: cancelLabel,
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.medium,
                          haptic: false,
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: confirmLabel,
                          variant: destructive
                              ? AppButtonVariant.danger
                              : AppButtonVariant.primary,
                          size: AppButtonSize.medium,
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.emphasized,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

/// Handle bar shown at the top of bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.gray300,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
