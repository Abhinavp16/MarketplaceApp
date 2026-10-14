import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import 'pressable.dart';

/// A number that rolls up when it grows and down when it shrinks.
class RollingNumber extends StatefulWidget {
  const RollingNumber({super.key, required this.value, required this.style, this.format});

  final num value;
  final TextStyle style;
  final String Function(num value)? format;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  bool _up = true;

  @override
  void didUpdateWidget(RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _up = widget.value > oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.format?.call(widget.value) ??
        NumberFormatter.formatPrice(widget.value);
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.base),
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(text);
        final dy = (incoming ? 1 : -1) * (_up ? 0.6 : -0.6);
        return ClipRect(
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0, dy), end: Offset.zero)
                .animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, ?current],
      ),
      child: Text(
        text,
        key: ValueKey(text),
        style: widget.style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// "Add" that turns into a − n + stepper in place.
///
/// Quantities are in pieces or meters; [step] is the pack size for wholesalers
/// (so each tap adds one pack) and [minimum] is the first quantity added.
/// Going below [minimum] removes the item (reports 0).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    required this.addLabel,
    this.step = 1,
    this.minimum = 1,
    this.maximum,
    this.onLimitReached,
    this.displayQuantity,
    this.compact = false,
    this.enabled = true,
    this.expand = false,
    this.decreaseLabel = 'Decrease quantity',
    this.increaseLabel = 'Increase quantity',
    this.pill = false,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final String addLabel;
  final int step;
  final int minimum;
  final int? maximum;
  final VoidCallback? onLimitReached;

  /// What to show in the middle (e.g. packs instead of meters).
  final String Function(int quantity)? displayQuantity;
  final bool compact;
  final bool enabled;
  final bool expand;
  final String decreaseLabel;
  final String increaseLabel;

  /// Fully rounded ends instead of squircle corners.
  final bool pill;

  double get _height => compact ? 34 : 44;

  ShapeBorder _shape(
    BorderRadius radius, [
    BorderSide side = BorderSide.none,
  ]) => pill
      ? StadiumBorder(side: side)
      : RoundedSuperellipseBorder(borderRadius: radius, side: side);

  void _increase() {
    final next = quantity <= 0 ? minimum : quantity + step;
    if (maximum != null && next > maximum!) {
      HapticFeedback.mediumImpact();
      onLimitReached?.call();
      return;
    }
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  void _decrease() {
    final next = quantity - step;
    HapticFeedback.selectionClick();
    onChanged(next < minimum ? 0 : next);
  }

  @override
  Widget build(BuildContext context) {
    final radius = pill
        ? BorderRadius.circular(_height / 2)
        : BorderRadius.circular(compact ? AppRadius.sm : AppRadius.md);
    final showStepper = quantity > 0;
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.base),
      switchInCurve: AppMotion.emphasized,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: showStepper
          ? _stepper(context, radius)
          : _addButton(context, radius),
    );
  }

  Widget _addButton(BuildContext context, BorderRadius radius) {
    final button = Pressable(
      key: const ValueKey('add'),
      onTap: enabled ? _increase : null,
      borderRadius: radius,
      shape: _shape(radius),
      color: AppColors.surfaceLight,
      semanticLabel: addLabel,
      child: Container(
        height: _height,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
        decoration: ShapeDecoration(
          shape: _shape(
            radius,
            BorderSide(
              color: enabled ? AppColors.primary : AppColors.border,
              width: 1.4,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          addLabel,
          maxLines: 1,
          style: AppFonts.jakarta(
            fontSize: compact ? 13 : 15,
            fontWeight: FontWeight.w800,
            color: enabled ? AppColors.primary : AppColors.textDisabled,
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _stepper(BuildContext context, BorderRadius radius) {
    final atMax = maximum != null && quantity + step > maximum!;
    final iconSize = compact ? 16.0 : 18.0;
    final label = displayQuantity?.call(quantity) ??
        NumberFormatter.formatQuantity(quantity);
    Widget side(IconData icon, VoidCallback onTap, String semantic, {bool dim = false}) {
      return Semantics(
        button: true,
        label: semantic,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          // Full-width card steppers have room for 44 px wide buttons, an
          // easier tap than the 34 px compact square.
          child: SizedBox(
            width: compact && !expand ? 34 : 44,
            height: _height,
            child: Center(
              child: HugeIcon(
                icon: icon,
                size: iconSize,
                color: Colors.white.withValues(alpha: dim ? 0.55 : 1),
              ),
            ),
          ),
        ),
      );
    }

    final stepper = Material(
      key: const ValueKey('stepper'),
      color: AppColors.primary,
      shape: _shape(radius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _height,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            side(
              quantity - step < minimum
                  ? HugeIcons.strokeRoundedDelete02
                  : HugeIcons.strokeRoundedMinusSign,
              _decrease,
              decreaseLabel,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: compact ? 22 : 30),
              child: Center(
                child: RollingNumber(
                  value: quantity,
                  format: (_) => label,
                  style: AppFonts.jakarta(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            side(HugeIcons.strokeRoundedPlusSign, _increase, increaseLabel,
                dim: atMax),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: stepper) : stepper;
  }
}
