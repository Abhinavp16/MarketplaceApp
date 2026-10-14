import 'dart:ui' as ui show FragmentProgram, FragmentShader;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';

/// A fully rounded teal track with a white knob: slide the knob to the end
/// to confirm. Every couple of seconds a wave of light sweeps along the
/// track and reveals dithered arrows pointing the way.
///
/// It behaves like rubber: pulling past the end stretches the pill (with
/// resistance) and squeezes it a little thinner; letting go past the middle
/// springs the knob to the end and confirms; letting go before the middle
/// springs it back, its overshoot stretching the pill to the left. While
/// [onConfirmed] runs (or [loading] is set) the knob waits at the end with a
/// spinner, then returns. Screen readers get a plain button that confirms on
/// tap.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon = HugeIcons.strokeRoundedArrowRight01,
    this.loading = false,
  });

  final String label;

  /// Called once the knob reaches the end; null disables the slider.
  final Future<void> Function()? onConfirmed;
  final IconData icon;
  final bool loading;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  static const double _height = 56;
  static const double _inset = 4;
  static const double _knob = _height - _inset * 2;

  /// Let go past this share of the way and it confirms.
  static const double _confirmAt = 0.5;

  /// The most the pill stretches, in logical pixels.
  static const double _maxStretch = 22;

  /// Where the knob is: 0 at the start, 1 at the end. It can go a little
  /// past either end (springs overshooting, pulling past the end); that
  /// overshoot is what stretches the pill.
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: AppMotion.springDuration,
    lowerBound: -0.5,
    upperBound: 1.5,
    value: 0,
  );

  /// Where the finger would have put the knob, before the rubber band.
  double _rawDrag = 0;
  bool _running = false;
  bool _hitEnd = false;

  bool get _enabled =>
      widget.onConfirmed != null && !widget.loading && !_running;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// Past the end the knob follows the finger less and less: a rubber band
  /// that tops out at [_maxStretch].
  double _rubber(double over, double travel) {
    final px = over * travel;
    final stretched = _maxStretch * (1 - 1 / (1 + px / (_maxStretch * 2)));
    return stretched / travel;
  }

  void _dragStart() {
    if (!_enabled) return;
    _progress.stop();
    _rawDrag = _progress.value.clamp(0.0, 1.0);
    _hitEnd = false;
  }

  void _drag(DragUpdateDetails details, double travel) {
    if (!_enabled || travel <= 0) return;
    _rawDrag = (_rawDrag + details.delta.dx / travel).clamp(-0.2, 3.0);
    final next = _rawDrag <= 1
        ? _rawDrag.clamp(0.0, 1.0)
        : 1 + _rubber(_rawDrag - 1, travel);
    // A tick when the knob first meets the end.
    if (next >= 1 && !_hitEnd) {
      _hitEnd = true;
      HapticFeedback.lightImpact();
    } else if (next < 0.98) {
      _hitEnd = false;
    }
    _progress.value = next;
  }

  void _release() {
    if (!_enabled) return;
    if (_progress.value >= _confirmAt) {
      _confirm();
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _progress.animateTo(
      0,
      duration: AppMotion.of(context, AppMotion.springDuration),
      curve: AppMotion.spring,
    );
  }

  Future<void> _confirm() async {
    final onConfirmed = widget.onConfirmed;
    if (onConfirmed == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _running = true);
    // Springs to the end; pulled past it, it snaps back with a small bulge.
    await _progress.animateTo(
      1,
      duration: AppMotion.of(context, AppMotion.springDuration),
      curve: AppMotion.spring,
    );
    try {
      await onConfirmed();
    } finally {
      if (mounted) {
        setState(() => _running = false);
        _springBack();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _running || widget.loading;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: _enabled ? _confirm : null,
      child: Opacity(
        opacity: widget.onConfirmed == null ? 0.5 : 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final travel = constraints.maxWidth - _knob - _inset * 2;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _dragStart(),
              onHorizontalDragUpdate: (details) => _drag(details, travel),
              onHorizontalDragEnd: (_) => _release(),
              onHorizontalDragCancel: _release,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final v = _progress.value;
                  final t = v.clamp(0.0, 1.0);
                  // Overshoot past either end becomes stretch on that side.
                  final leftStretch = (-v * travel).clamp(0.0, _maxStretch);
                  final rightStretch = ((v - 1) * travel).clamp(
                    0.0,
                    _maxStretch,
                  );
                  // Stretched rubber gets a little thinner.
                  final squeeze = (leftStretch + rightStretch) * 0.08;
                  final knobLeft =
                      _inset + t * travel + rightStretch - leftStretch;

                  return SizedBox(
                    height: _height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The pill, which stretches past its box when pulled.
                        Positioned(
                          left: -leftStretch,
                          right: -rightStretch,
                          top: squeeze,
                          bottom: squeeze,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: AppColors.primary,
                              shape: const StadiumBorder(),
                              shadows: [
                                BoxShadow(
                                  color: AppColors.primaryDeep.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipPath(
                              clipper: const ShapeBorderClipper(
                                shape: StadiumBorder(),
                              ),
                              child: Stack(
                                children: [
                                  // Dithered arrows the shimmer reveals;
                                  // they fade as the knob is dragged.
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                                      child: _ShimmerArrows(
                                        start: _inset + _knob + 6 + leftStretch,
                                      ),
                                    ),
                                  ),
                                  // A lighter trail behind the knob.
                                  Positioned(
                                    left: _inset,
                                    top: (_inset - squeeze).clamp(0.0, _inset),
                                    bottom: (_inset - squeeze).clamp(
                                      0.0,
                                      _inset,
                                    ),
                                    // Up to the knob's right edge (the
                                    // left stretch cancels out here).
                                    width: _knob + t * travel + rightStretch,
                                    child: DecoratedBox(
                                      decoration: ShapeDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.16,
                                        ),
                                        shape: const StadiumBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // The label fades as the knob passes over it.
                        Positioned.fill(
                          left: _knob + _inset * 2,
                          right: _inset * 3,
                          child: Center(
                            child: Opacity(
                              opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: knobLeft,
                          top: _inset,
                          width: _knob,
                          height: _knob,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.card,
                            ),
                            child: Center(
                              child: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : HugeIcon(
                                      icon: widget.icon,
                                      size: 22,
                                      color: AppColors.primary,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The dithered arrows on the slider track, revealed by a sweeping band of
/// light (shaders/slider_arrows.frag). Off when the OS asks for reduced
/// motion; pauses with TickerMode.
class _ShimmerArrows extends StatefulWidget {
  const _ShimmerArrows({required this.start});

  /// Where the arrows begin, past the knob's resting place.
  final double start;

  @override
  State<_ShimmerArrows> createState() => _ShimmerArrowsState();
}

class _ShimmerArrowsState extends State<_ShimmerArrows>
    with SingleTickerProviderStateMixin {
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/slider_arrows.frag');

  // One cycle: the sweep, then a short rest.
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program.then((program) {
      if (mounted) setState(() => _shader = program.fragmentShader());
    }, onError: (Object _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _cycle.stop();
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null || AppMotion.reduced(context)) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: CustomPaint(painter: _ArrowsPainter(shader, _cycle, widget.start)),
    );
  }
}

class _ArrowsPainter extends CustomPainter {
  _ArrowsPainter(this.shader, this.cycle, this.start) : super(repaint: cycle);

  final ui.FragmentShader shader;
  final AnimationController cycle;
  final double start;

  /// The sweep takes this share of each cycle; the rest is a pause.
  static const double _sweepShare = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final v = cycle.value;
    // Band centre runs from just off the left to just off the right.
    final wave = v < _sweepShare
        ? -0.2 + 1.4 * Curves.easeInOut.transform(v / _sweepShare)
        : -1.0;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, wave)
      ..setFloat(3, 2)
      ..setFloat(4, start)
      // White dots at up to 55% opacity.
      ..setFloat(5, 1)
      ..setFloat(6, 1)
      ..setFloat(7, 1)
      ..setFloat(8, 0.55);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ArrowsPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.cycle != cycle ||
      oldDelegate.start != start;
}
