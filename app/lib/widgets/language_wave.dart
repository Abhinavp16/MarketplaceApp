import 'dart:async';
import 'dart:ui'
    as ui
    show FragmentProgram, FragmentShader, Image, PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding;

import '../core/theme/app_theme.dart';

/// Wraps the whole app (MaterialApp.builder) so a language switch can play
/// as a wave: the screen is captured in the old language, laid exactly over
/// the app while it switches underneath, then dissolved by a curved,
/// dithered wave running from the top-left to the bottom-right
/// (shaders/language_wave.frag). Switch the language through
/// [LanguageWave.run].
class LanguageWave extends StatefulWidget {
  const LanguageWave({super.key, required this.child});

  final Widget child;

  /// Runs [change] (which switches the language) behind the wave. [settle]
  /// waits for a closing menu or sheet to finish first, so it isn't in the
  /// captured screen. Without the wave (reduced motion, no shader support,
  /// or no [LanguageWave] above [context]) it just runs [change].
  static Future<void> run(
    BuildContext context,
    Future<void> Function() change, {
    Duration settle = Duration.zero,
  }) {
    final state = context.findAncestorStateOfType<_LanguageWaveState>();
    if (state == null) return change();
    return state._run(change, settle);
  }

  @override
  State<LanguageWave> createState() => _LanguageWaveState();
}

class _LanguageWaveState extends State<LanguageWave>
    with SingleTickerProviderStateMixin {
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/language_wave.frag');

  final GlobalKey _boundary = GlobalKey();
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _wave,
    curve: Curves.easeInOutSine,
  );
  ui.FragmentShader? _shader;
  ui.Image? _snapshot;
  // A 1x1 image the shader is drawn with once, invisibly, so its first real
  // use doesn't stall on compiling it (and the wave doesn't skip ahead).
  ui.Image? _warmUp;
  Timer? _warmUpTimer;

  @override
  void initState() {
    super.initState();
    _program.then((program) {
      if (!mounted) return;
      _shader = program.fragmentShader();
      // After start-up settles, not competing with the first screens.
      _warmUpTimer = Timer(const Duration(seconds: 3), _startWarmUp);
    }, onError: (Object _) {});
  }

  Future<void> _startWarmUp() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawPaint(Paint()..color = Colors.transparent);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();
    if (!mounted || _snapshot != null) {
      image.dispose();
      return;
    }
    setState(() => _warmUp = image);
    // Drawn for a frame, then gone.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _warmUp = null);
    image.dispose();
  }

  @override
  void dispose() {
    _warmUpTimer?.cancel();
    _wave.dispose();
    _snapshot?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() change, Duration settle) async {
    // Already waving, no shader, or motion reduced: just switch.
    if (_snapshot != null || _shader == null || AppMotion.reduced(context)) {
      return change();
    }
    ui.Image? image;
    try {
      if (settle > Duration.zero) await Future<void>.delayed(settle);
      await SchedulerBinding.instance.endOfFrame;
      final boundary =
          _boundary.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null && mounted) {
        image = await boundary.toImage(
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
      }
    } catch (_) {
      image = null;
    }
    if (image == null || !mounted || _snapshot != null) {
      image?.dispose();
      return change();
    }

    // Strict order, so the new language never shows before the cover:
    // 1. The snapshot goes on top (it looks exactly like the screen) and is
    //    given two frames to be on the display.
    _wave.value = 0;
    setState(() => _snapshot = image);
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return change();
    // 2. The language switches underneath it, and the new screen gets two
    //    frames to build.
    final switched = change();
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return switched;
    // 3. The wave reveals it.
    _wave.forward(from: 0).whenCompleteOrCancel(() {
      if (!mounted) return;
      final old = _snapshot;
      setState(() => _snapshot = null);
      old?.dispose();
    });
    await switched;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final shader = _shader;
    final warmUp = _warmUp;
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        // Fully revealed (progress 1): draws nothing visible.
        if (warmUp != null && shader != null && snapshot == null)
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WavePainter(
                  shader,
                  warmUp,
                  const AlwaysStoppedAnimation(1),
                ),
              ),
            ),
          ),
        if (snapshot != null && shader != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WavePainter(shader, snapshot, _progress),
              ),
            ),
          ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.shader, this.image, this.progress)
    : super(repaint: progress);

  final ui.FragmentShader shader;
  final ui.Image image;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    const tint = AppColors.primary;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, progress.value)
      // Dot size, like the Home header's dither.
      ..setFloat(3, 3)
      ..setFloat(4, tint.r)
      ..setFloat(5, tint.g)
      ..setFloat(6, tint.b)
      ..setFloat(7, 0.55)
      ..setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.image != image || old.shader != shader;
}
