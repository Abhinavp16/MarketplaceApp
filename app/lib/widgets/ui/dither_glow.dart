import 'dart:async';
import 'dart:ui' as ui show FragmentProgram, FragmentShader;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Light drawn as small white dots (an ordered dither), pooled in the
/// top-right corner, with a band of dots sweeping across every few seconds.
/// Lay it over a teal surface (the Home header, the accepted-deal card).
/// The sweep stays off when the OS asks for reduced motion and pauses with
/// TickerMode; without shader support it draws nothing.
class DitherGlow extends StatefulWidget {
  const DitherGlow({super.key, this.opacity = 0.12, this.cell = 3});

  /// Opacity of the white dots.
  final double opacity;

  /// Dot size in logical pixels.
  final double cell;

  @override
  State<DitherGlow> createState() => _DitherGlowState();
}

class _DitherGlowState extends State<DitherGlow>
    with SingleTickerProviderStateMixin {
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/header_dither.frag');

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  ui.FragmentShader? _shader;
  Timer? _first;
  Timer? _every;

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
    _first?.cancel();
    _every?.cancel();
    if (AppMotion.reduced(context)) {
      _sweep.stop();
      return;
    }
    void run() {
      if (mounted) _sweep.forward(from: 0);
    }

    _first = Timer(const Duration(milliseconds: 900), run);
    _every = Timer.periodic(const Duration(seconds: 5), (_) => run());
  }

  @override
  void dispose() {
    _first?.cancel();
    _every?.cancel();
    _sweep.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DitherPainter(shader, _sweep, widget.cell, widget.opacity),
      ),
    );
  }
}

class _DitherPainter extends CustomPainter {
  _DitherPainter(this.shader, this.sweep, this.cell, this.opacity)
    : super(repaint: sweep);

  final ui.FragmentShader shader;
  final AnimationController sweep;
  final double cell;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final position = sweep.isAnimating
        ? Curves.easeInOutCubic.transform(sweep.value)
        : -1.0;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, position)
      ..setFloat(3, cell)
      // White dots.
      ..setFloat(4, 1)
      ..setFloat(5, 1)
      ..setFloat(6, 1)
      ..setFloat(7, opacity);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_DitherPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.sweep != sweep ||
      oldDelegate.cell != cell ||
      oldDelegate.opacity != opacity;
}
