import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/app_image.dart';

// Building blocks of the product detail page.

/// Full-screen photo viewer: swipe between photos, pinch or double-tap to
/// zoom. Pops with the index of the photo on screen.
class PdpImageViewer extends StatefulWidget {
  const PdpImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.category,
    required this.name,
  });

  /// `url` and `blurHash` of each photo.
  final List<Map<String, String>> images;
  final int initialIndex;
  final String category;
  final String name;

  @override
  State<PdpImageViewer> createState() => _PdpImageViewerState();
}

class _PdpImageViewerState extends State<PdpImageViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  final Map<int, TransformationController> _transforms = {};
  bool _zoomed = false;
  Offset _doubleTapAt = Offset.zero;
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  );
  late final CurvedAnimation _zoomCurve = CurvedAnimation(
    parent: _zoom,
    curve: AppMotion.standard,
  );
  Animation<Matrix4>? _zoomTween;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _transformFor(_index).value = tween.value;
    });
  }

  @override
  void dispose() {
    _zoomCurve.dispose();
    _zoom.dispose();
    _pages.dispose();
    for (final controller in _transforms.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _transformFor(int index) {
    return _transforms.putIfAbsent(index, () {
      final controller = TransformationController();
      controller.addListener(() {
        if (index != _index) return;
        final zoomed = controller.value.getMaxScaleOnAxis() > 1.01;
        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
      });
      return controller;
    });
  }

  void _toggleZoom() {
    final controller = _transformFor(_index);
    final Matrix4 target;
    if (controller.value.getMaxScaleOnAxis() > 1.01) {
      target = Matrix4.identity();
    } else {
      const scale = 2.5;
      target = Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(
          -_doubleTapAt.dx * (scale - 1),
          -_doubleTapAt.dy * (scale - 1),
          0,
        );
    }
    if (AppMotion.reduced(context)) {
      controller.value = target;
      return;
    }
    _zoomTween = Matrix4Tween(
      begin: controller.value.clone(),
      end: target,
    ).animate(_zoomCurve);
    _zoom.forward(from: 0);
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = widget.images.length;
    final padding = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: total,
                onPageChanged: (index) {
                  _transforms[_index]?.value = Matrix4.identity();
                  setState(() {
                    _index = index;
                    _zoomed = false;
                  });
                },
                itemBuilder: (context, index) {
                  final data = widget.images[index];
                  return GestureDetector(
                    onDoubleTapDown: (details) =>
                        _doubleTapAt = details.localPosition,
                    onDoubleTap: _toggleZoom,
                    child: InteractiveViewer(
                      transformationController: _transformFor(index),
                      minScale: 1,
                      maxScale: 4,
                      child: SizedBox.expand(
                        child: AppImage(
                          imageUrl: data['url'] ?? '',
                          blurHash: data['blurHash'],
                          category: widget.category,
                          name: widget.name,
                          fit: BoxFit.contain,
                          // Zooms up to 4x, so keep every pixel.
                          fullResolution: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: padding.top + 8,
                left: 16,
                right: 8,
                child: Row(
                  children: [
                    if (total > 1)
                      Text(
                        '${_index + 1} / $total',
                        style: AppText.price(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: l10n.commonClose,
                      onPressed: _close,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        fixedSize: const Size(44, 44),
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (total > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: padding.bottom + 24,
                  child: Semantics(
                    label: l10n.pdpImageOf(_index + 1, total),
                    child: PdpPageDots(
                      count: total,
                      index: _index,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of page dots; the current one is a short bar.
class PdpPageDots extends StatelessWidget {
  const PdpPageDots({
    super.key,
    required this.count,
    required this.index,
    this.activeColor = AppColors.primary,
    this.inactiveColor = AppColors.gray300,
  });

  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.base);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: duration,
          curve: AppMotion.standard,
          width: i == index ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i == index ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

/// A specification is "generic" when the admin entered only a feature line
/// (keys like `feature_1`); those show as a list rather than as key / value.
bool pdpIsFeatureSpec(Map<String, dynamic> spec) {
  final key = spec['key']?.toString().trim() ?? '';
  return key.isEmpty || key.toLowerCase().startsWith('feature_');
}

/// Short key / value specs worth highlighting (e.g. size, power).
List<MapEntry<String, String>> pdpKeySpecs(
  List<Map<String, dynamic>> specs, {
  int max = 4,
  int maxValueLength = 28,
}) {
  final result = <MapEntry<String, String>>[];
  for (final spec in specs) {
    if (pdpIsFeatureSpec(spec)) continue;
    final key = spec['key']?.toString().trim() ?? '';
    final value = spec['value']?.toString().trim() ?? '';
    if (value.isEmpty || value.length > maxValueLength) continue;
    result.add(MapEntry(key, value));
    if (result.length == max) break;
  }
  return result;
}

/// Horizontal strip of key specs: label over value.
class PdpKeySpecStrip extends StatelessWidget {
  const PdpKeySpecStrip({super.key, required this.specs});

  final List<MapEntry<String, String>> specs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < specs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 96, maxWidth: 150),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    specs[i].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.jakarta(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    specs[i].value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Specifications as one column: key / value rows first, then the feature
/// lines under a "Features" heading. Alternate rows are shaded. With [limit],
/// only that many rows are shown.
class PdpSpecTable extends StatelessWidget {
  const PdpSpecTable({
    super.key,
    required this.specs,
    required this.featuresLabel,
    this.limit,
  });

  final List<Map<String, dynamic>> specs;
  final String featuresLabel;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final details = specs.where((s) => !pdpIsFeatureSpec(s)).toList();
    final features = specs.where(pdpIsFeatureSpec).toList();
    var remaining = limit ?? (details.length + features.length);
    final shownDetails = details.take(remaining).toList();
    remaining -= shownDetails.length;
    final shownFeatures = features.take(remaining < 0 ? 0 : remaining).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shownDetails.length; i++)
          _row(
            shaded: i.isEven,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    shownDetails[i]['key']?.toString() ?? '',
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    shownDetails[i]['value']?.toString() ?? '',
                    style: AppFonts.jakarta(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (shownFeatures.isNotEmpty) ...[
          if (shownDetails.isNotEmpty) const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Text(featuresLabel.toUpperCase(), style: AppText.eyebrow()),
          ),
          for (var i = 0; i < shownFeatures.length; i++)
            _row(
              shaded: i.isEven,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shownFeatures[i]['value']?.toString() ?? '',
                      style: AppFonts.jakarta(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _row({required bool shaded, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: shaded ? AppColors.gray50 : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: child,
    );
  }
}

/// The shop's promises, as a static 3 × 2 grid.
class PdpTrustBadges extends StatelessWidget {
  const PdpTrustBadges({super.key});

  static final List<(IconData, String Function(AppLocalizations))> _badges = [
    (
      HugeIcons.strokeRoundedCheckmarkBadge01,
      (l10n) => l10n.productTrustVerifiedProducts,
    ),
    (HugeIcons.strokeRoundedStar, (l10n) => l10n.productTrustReviews),
    (HugeIcons.strokeRoundedCustomerSupport, (l10n) => l10n.productTrustSupport),
    (
      HugeIcons.strokeRoundedTruckDelivery,
      (l10n) => l10n.productTrustFastDelivery,
    ),
    (
      HugeIcons.strokeRoundedSecurityCheck,
      (l10n) => l10n.productTrustSecurePayments,
    ),
    (
      HugeIcons.strokeRoundedReturnRequest,
      (l10n) => l10n.productTrustEasyReturns,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            for (final badge in _badges)
              SizedBox(
                width: width,
                child: Column(
                  children: [
                    HugeIcon(icon: badge.$1, size: 22, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(
                      badge.$2(l10n),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
