import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Shrinks its child slightly while a finger is down. Uses a [Listener], so it
/// never competes with the child's own gestures (buttons, InkWells).
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (!widget.enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return Listener(
      onPointerDown: (event) {
        // A control inside (a card's heart or Add button) took this touch.
        if (PressScaleExclude.claims(event.pointer)) return;
        _set(true);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduced ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : AppMotion.base,
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Wrap a control that sits inside a [PressScale] (a card's heart or Add
/// button) so pressing it doesn't shrink the surrounding card. The control's
/// own press effects still play.
///
/// Pointer-down reaches the innermost listener first, so this marks the
/// touch before the outer [PressScale] sees it.
class PressScaleExclude extends StatelessWidget {
  const PressScaleExclude({super.key, required this.child});

  final Widget child;

  static final Set<int> _claimed = {};

  static bool claims(int pointer) => _claimed.contains(pointer);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _claimed.add(event.pointer),
      onPointerUp: (event) => _claimed.remove(event.pointer),
      onPointerCancel: (event) => _claimed.remove(event.pointer),
      child: child,
    );
  }
}

/// A tappable surface: ripple, a gentle press scale, optional haptic tick and
/// a screen-reader label. Use it for cards, tiles and custom buttons instead of
/// a bare GestureDetector.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.scale = 0.97,
    this.haptic = false,
    this.semanticLabel,
    this.color = Colors.transparent,
    this.splashColor,
    this.shape,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final double scale;
  final bool haptic;
  final String? semanticLabel;
  final Color color;
  final Color? splashColor;

  /// Outline for the ripple and clip instead of [borderRadius]; buttons pass
  /// [AppShapes.squircle].
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final enabled = onTap != null || onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: PressScale(
        scale: scale,
        enabled: enabled,
        child: Material(
          color: color,
          shape: shape,
          borderRadius: shape == null ? radius : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: shape == null ? radius : null,
            customBorder: shape,
            splashColor:
                splashColor ?? AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            onTap: onTap == null
                ? null
                : () {
                    if (haptic) HapticFeedback.selectionClick();
                    onTap!();
                  },
            onLongPress: onLongPress,
            child: child,
          ),
        ),
      ),
    );
  }
}
