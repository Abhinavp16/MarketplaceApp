import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Plays one staggered entrance for the [StaggeredRevealItem]s below it: each
/// fades in and drifts up a little, one after another. It plays once, when
/// this widget first appears; items built later (scrolled into view, the next
/// page) just show. Skipped when the OS asks for reduced motion.
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({super.key, required this.child});

  final Widget child;

  /// Items past this index aren't staggered (they start off screen).
  static const int maxStaggered = 8;
  // Long enough apart that items visibly arrive one by one.
  static const int _stepMs = 120;
  static const int _itemMs = 420;
  static const int _totalMs = _itemMs + _stepMs * (maxStaggered - 1);

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: StaggeredReveal._totalMs),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
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
    return _RevealScope(animation: _controller, child: widget.child);
  }
}

class _RevealScope extends InheritedWidget {
  const _RevealScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_RevealScope oldWidget) =>
      oldWidget.animation != animation;
}

/// One item of a [StaggeredReveal]; [index] sets its place in the sequence.
class StaggeredRevealItem extends StatelessWidget {
  const StaggeredRevealItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RevealScope>();
    final animation = scope?.animation;
    if (animation == null ||
        animation.isCompleted ||
        index >= StaggeredReveal.maxStaggered) {
      return child;
    }
    const total = StaggeredReveal._totalMs;
    final startMs = index * StaggeredReveal._stepMs;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t =
            ((animation.value * total - startMs) / StaggeredReveal._itemMs)
                .clamp(0.0, 1.0);
        final v = AppMotion.emphasized.transform(t);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}
