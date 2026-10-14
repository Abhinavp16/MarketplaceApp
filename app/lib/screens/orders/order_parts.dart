// Presentational pieces shared by the order screens (history, tracking,
// success) and the checkout result dialog.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/customer_order_presentation.dart';
import '../../widgets/ui/ui.dart';

/// Green check in a soft circle that pops in once (scale + fade), optionally
/// with a few confetti dots. Static when the user reduces motion.
class OrderSuccessBadge extends StatefulWidget {
  /// Badge of [size]; [confetti] adds the dots; [animate] false shows the
  /// final state straight away (e.g. when it already played).
  const OrderSuccessBadge({
    super.key,
    this.size = 72,
    this.confetti = true,
    this.animate = true,
    this.icon = HugeIcons.strokeRoundedCheckmarkCircle02,
  });

  final double size;
  final bool confetti;
  final bool animate;
  final IconData icon;

  @override
  State<OrderSuccessBadge> createState() => _OrderSuccessBadgeState();
}

class _OrderSuccessBadgeState extends State<OrderSuccessBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final showConfetti =
        widget.confetti && widget.animate && !AppMotion.reduced(context);
    final scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.3, curve: Curves.easeOut),
    );
    final badge = FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1).animate(scale),
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: HugeIcon(
              icon: widget.icon,
              size: size * 0.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
    if (!showConfetti) return badge;
    final extent = size * 2;
    return SizedBox(
      width: extent,
      height: extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(
                    progress: _controller.value,
                    radius: size * 0.5,
                  ),
                ),
              ),
            ),
          ),
          badge,
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.radius});

  final double progress;
  final double radius;

  static const _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.primaryDark,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Dots leave the badge edge after it has popped, drift out and fade.
    final t = ((progress - 0.2) / 0.8).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return;
    final eased = Curves.easeOutCubic.transform(t);
    final opacity = (1 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    const count = 10;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (i.isEven ? 0.18 : -0.12);
      final distance = radius * (1.05 + eased * (i.isEven ? 0.8 : 0.55));
      final offset =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: opacity);
      final dot = i % 3 == 0 ? 4.0 : 3.0;
      canvas.drawCircle(offset, dot, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.radius != radius;
}

/// Thin rounded progress bar for an order's journey.
class OrderProgressBar extends StatelessWidget {
  /// Fills [value] (0–1) of the track in [color].
  const OrderProgressBar({super.key, required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: AppColors.gray100)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical tracker: every step of the journey, reached steps in green, the
/// current one highlighted, upcoming ones in grey, a stopped one in red.
class OrderStepTracker extends StatelessWidget {
  /// One row per step; [label] names a stage, [subtitle] gives its date line
  /// (null hides it), [currentBadge] is the chip on the current step.
  const OrderStepTracker({
    super.key,
    required this.steps,
    required this.label,
    required this.subtitle,
    this.currentBadge,
  });

  final List<OrderJourneyStep> steps;
  final String Function(String stage) label;
  final String? Function(OrderJourneyStep step) subtitle;
  final String? currentBadge;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            title: label(steps[i].stage),
            subtitle: subtitle(steps[i]),
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            nextReached:
                i + 1 < steps.length &&
                steps[i + 1].state != OrderStepState.upcoming,
            badge: steps[i].state == OrderStepState.current
                ? currentBadge
                : null,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.isFirst,
    required this.isLast,
    required this.nextReached,
    this.badge,
  });

  final OrderJourneyStep step;
  final String title;
  final String? subtitle;
  final bool isFirst;
  final bool isLast;
  final bool nextReached;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final state = step.state;
    final (Color fill, Color fg, IconData icon) = switch (state) {
      OrderStepState.done => (
        AppColors.primary,
        Colors.white,
        HugeIcons.strokeRoundedTick02,
      ),
      OrderStepState.current => (
        AppColors.primarySoft,
        AppColors.primary,
        CustomerOrderPresentation.hugeIcon(step.stage),
      ),
      OrderStepState.stopped => (
        AppColors.errorSoft,
        AppColors.error,
        CustomerOrderPresentation.hugeIcon(step.stage),
      ),
      OrderStepState.upcoming => (
        AppColors.gray100,
        AppColors.textDisabled,
        CustomerOrderPresentation.hugeIcon(step.stage),
      ),
    };
    final lineColor = nextReached ? AppColors.primary : AppColors.gray200;
    final titleColor = switch (state) {
      OrderStepState.upcoming => AppColors.textTertiary,
      OrderStepState.stopped => AppColors.error,
      _ => AppColors.textPrimary,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: state == OrderStepState.current
                        ? Border.all(color: AppColors.primary, width: 1.6)
                        : null,
                  ),
                  child: Center(
                    child: HugeIcon(icon: icon, size: 16, color: fg),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: state == OrderStepState.upcoming
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      if (badge != null)
                        StatusChip(
                          label: badge!,
                          tone: ChipTone.brand,
                          dense: true,
                        ),
                    ],
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        color: state == OrderStepState.upcoming
                            ? AppColors.textDisabled
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shaped like an order card, for list loading.
class OrderCardSkeleton extends StatelessWidget {
  /// One placeholder card.
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 120, height: 14),
              Spacer(),
              Skeleton(width: 70, height: 16),
            ],
          ),
          SizedBox(height: 8),
          Skeleton(width: 180, height: 12),
          SizedBox(height: 12),
          Skeleton(width: 130, height: 22, radius: AppRadius.pill),
          SizedBox(height: 12),
          Skeleton(height: 4, radius: AppRadius.pill),
        ],
      ),
    );
  }
}

/// Tinted panel with an icon, optional title and message (used for "what you
/// need to do" and stopped-order notes).
class OrderInfoPanel extends StatelessWidget {
  /// Panel in [tone] with [icon], [title] and [message].
  const OrderInfoPanel({
    super.key,
    required this.message,
    this.title,
    this.icon = HugeIcons.strokeRoundedInformationCircle,
    this.tone = ChipTone.info,
  });

  final String message;
  final String? title;
  final IconData icon;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      ChipTone.warning => (AppColors.warningSoft, AppColors.warning),
      ChipTone.error => (AppColors.errorSoft, AppColors.error),
      ChipTone.success ||
      ChipTone.brand => (AppColors.primarySoft, AppColors.primaryDeep),
      ChipTone.accent => (AppColors.accentSoft, AppColors.accent),
      ChipTone.neutral => (AppColors.gray100, AppColors.textSecondary),
      ChipTone.info => (AppColors.infoSoft, AppColors.secondary),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  message,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
