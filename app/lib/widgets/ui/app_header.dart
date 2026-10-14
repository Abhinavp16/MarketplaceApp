import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';

/// Round back button used by every screen header.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.onDark = false});

  final VoidCallback? onPressed;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.commonBack,
      onPressed:
          onPressed ??
          () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
      style: IconButton.styleFrom(
        backgroundColor: onDark
            ? Colors.white.withValues(alpha: 0.16)
            : AppColors.surfaceLight,
        side: onDark ? null : const BorderSide(color: AppColors.border),
        fixedSize: const Size(44, 44),
      ),
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedArrowLeft01,
        size: 22,
        color: onDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }
}

/// Screen header: back button, title (with optional subtitle) and actions.
/// Use as `appBar: AppHeader(title: ...)`.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.backgroundColor = AppColors.backgroundLight,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Color backgroundColor;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: EdgeInsets.only(left: showBack ? 10 : 16, right: 8),
                child: Row(
                  children: [
                    if (showBack) ...[
                      AppBackButton(onPressed: onBack),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      // The bar's height is fixed, so its title and subtitle
                      // stop growing at 1.3x text size instead of clipping.
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.jakarta(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.jakarta(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Round icon button for header actions (share, filter, clear...).
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = AppColors.textPrimary,
    this.badge,
    this.onDark = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;

  /// Translucent white style for dark or coloured headers. (No backdrop
  /// blur: on the Home header only flat teal sits behind it.)
  final bool onDark;

  /// Small count bubble; hidden when null or 0.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    Widget button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: onDark
            ? Colors.white.withValues(alpha: 0.14)
            : AppColors.surfaceLight,
        side: BorderSide(
          color: onDark
              ? Colors.white.withValues(alpha: 0.22)
              : AppColors.border,
        ),
        fixedSize: const Size(44, 44),
      ),
      icon: HugeIcon(
        icon: icon,
        size: 21,
        color: onDark ? Colors.white : color,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if ((badge ?? 0) > 0)
          Positioned(
            right: 2,
            top: 2,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge! > 99 ? '99+' : '$badge',
                  style: AppFonts.jakarta(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
