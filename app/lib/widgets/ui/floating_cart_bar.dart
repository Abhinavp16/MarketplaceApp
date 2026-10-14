import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/cart_provider.dart';
import '../../core/providers/guest_mode_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../l10n/l10n.dart';
import '../app_image.dart';
import 'pressable.dart';
import 'quantity_stepper.dart';

// The pill's resizing and the thumbnails' moves use the shared spring.
const Duration _springDuration = AppMotion.springDuration;
const Curve _spring = AppMotion.spring;

/// Frosted teal pill that rises from the bottom while the cart has items:
/// round thumbnails of the newest items, item count, total and an arrow.
/// It's only as wide as its contents, sits at the left (in line with the
/// page's 16 px gutter), and springs to its new width as things change.
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({
    super.key,
    required this.onTap,
    this.visible = true,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 10),
  });

  final VoidCallback onTap;

  /// Space around the pill; zero when the host places it exactly (Home pins
  /// it to the floating nav).
  final EdgeInsetsGeometry margin;

  /// Lets the host hide the bar (e.g. on the cart tab) with the same motion.
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final isWholesaler = ref.watch(effectiveIsWholesalerProvider);
    final count = cart.displayItemCount(isWholesaler);
    final show = visible && cart.items.isNotEmpty;
    final l10n = context.l10n;
    final duration = AppMotion.of(context, AppMotion.slow);

    // While hidden it also folds its height away, so a host that stacks it
    // above something (Home puts it over the floating nav) doesn't keep
    // the empty space. It never clips, so the slide-out still shows.
    return AnimatedAlign(
      duration: duration,
      curve: show ? AppMotion.emphasized : AppMotion.exit,
      alignment: Alignment.bottomLeft,
      widthFactor: 1,
      heightFactor: show ? 1 : 0,
      child: IgnorePointer(
        ignoring: !show,
        child: AnimatedSlide(
          offset: show ? Offset.zero : const Offset(0, 1.6),
          duration: duration,
          curve: show ? AppMotion.emphasized : AppMotion.exit,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: duration,
            child: Padding(
              padding: margin,
              child: Align(
                alignment: Alignment.bottomLeft,
                // Only as wide as the pill.
                widthFactor: 1,
                // The shadow sits outside the pill's clip so it isn't cut off.
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    shadows: [
                      BoxShadow(
                        color: AppColors.primaryDeep.withValues(alpha: 0.26),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Pressable(
                    onTap: onTap,
                    haptic: true,
                    shape: const StadiumBorder(),
                    semanticLabel:
                        '${l10n.productViewCart}, ${l10n.commonItemsCount(count)}',
                    // Frosted glass: the page behind shows through, blurred.
                    // Grouped, so it shares the nav's backdrop read. Its own
                    // rounded clip: under the press-scale transform the
                    // Material's path clip is lost around a blur and the
                    // pill turns square.
                    child: ClipRRect(
                      // Fully round ends at any height.
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter.grouped(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          // At least [_height]; grows with a larger text
                          // size instead of clipping the two lines.
                          constraints: const BoxConstraints(minHeight: _height),
                          color: AppColors.primary.withValues(alpha: 0.82),
                          // The round thumbnails sit concentric with the pill's ends.
                          padding: const EdgeInsets.only(
                            left: (_height - _Thumbs.size) / 2,
                            right: 16,
                            top: 4,
                            bottom: 4,
                          ),
                          // The thumbnails and the text each spring to their
                          // new widths, so the text slides along as the pill
                          // grows instead of jumping.
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Thumbs(items: cart.items),
                              const SizedBox(width: 10),
                              AnimatedSize(
                                duration: AppMotion.of(
                                  context,
                                  _springDuration,
                                ),
                                curve: _spring,
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RollingNumber(
                                      value: count,
                                      format: (value) =>
                                          l10n.commonItemsCount(value.toInt()),
                                      style: AppFonts.jakarta(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                    RollingNumber(
                                      value: cart.subtotal,
                                      format: (value) =>
                                          '₹${NumberFormatter.formatPrice(value)}',
                                      style: AppFonts.jakarta(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                size: 20,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _height = 58;
}

/// Overlapping round thumbnails of the newest cart items (up to three). A
/// new item pops in at the right, a removed one shrinks away where it was,
/// and the rest slide into their new places.
class _Thumbs extends StatefulWidget {
  const _Thumbs({required this.items});

  final List<CartItem> items;

  static const double size = 36;
  static const double _overlap = 14;
  static const int _max = 3;

  @override
  State<_Thumbs> createState() => _ThumbsState();
}

class _ThumbEntry {
  _ThumbEntry(this.item);

  CartItem item;
  bool leaving = false;
  int slot = 0;

  String get key => item.cartItemKey;
}

class _ThumbsState extends State<_Thumbs> {
  // Shown thumbnails in order, and ones still shrinking away.
  final List<_ThumbEntry> _entries = [];
  final List<_ThumbEntry> _leaving = [];

  List<CartItem> get _newest {
    final items = widget.items;
    return items.length <= _Thumbs._max
        ? items
        : items.sublist(items.length - _Thumbs._max);
  }

  @override
  void initState() {
    super.initState();
    _entries.addAll(_newest.map(_ThumbEntry.new));
  }

  @override
  void didUpdateWidget(_Thumbs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final exit = AppMotion.of(context, _springDuration);
    final next = _newest;
    final nextKeys = {for (final item in next) item.cartItemKey};

    for (final entry in [..._entries]) {
      if (nextKeys.contains(entry.key)) continue;
      _entries.remove(entry);
      entry.leaving = true;
      _leaving.add(entry);
      Future<void>.delayed(exit, () {
        if (mounted && _leaving.remove(entry)) setState(() {});
      });
    }

    final current = {for (final entry in _entries) entry.key: entry};
    final ordered = <_ThumbEntry>[];
    for (final item in next) {
      var entry = current[item.cartItemKey];
      if (entry == null) {
        // Added back while still shrinking away: grow it again.
        final back = _leaving.where((e) => e.key == item.cartItemKey);
        if (back.isNotEmpty) {
          entry = back.first;
          _leaving.remove(entry);
          entry.leaving = false;
        } else {
          entry = _ThumbEntry(item);
        }
      }
      entry.item = item;
      ordered.add(entry);
    }
    _entries
      ..clear()
      ..addAll(ordered);
  }

  @override
  Widget build(BuildContext context) {
    const size = _Thumbs.size;
    const step = size - _Thumbs._overlap;
    final duration = AppMotion.of(context, _springDuration);
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].slot = i;
    }
    final count = _entries.isEmpty ? 1 : _entries.length;

    Widget thumb(_ThumbEntry entry) => AnimatedPositioned(
      key: ValueKey(entry.key),
      duration: duration,
      curve: _spring,
      left: entry.slot * step,
      top: 0,
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        // Grows in when first shown; shrinks away when leaving.
        tween: Tween(begin: 0, end: entry.leaving ? 0 : 1),
        duration: duration,
        curve: _spring,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.4 + 0.6 * v, child: child),
        ),
        child: _ThumbImage(item: entry.item),
      ),
    );

    // The row's width springs to fit, carrying the text beside it along.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: size + (count - 1) * step),
      duration: duration,
      curve: _spring,
      builder: (context, width, child) =>
          SizedBox(width: width, height: size, child: child),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Leaving ones underneath, so the others slide over them.
          for (final entry in _leaving) thumb(entry),
          for (final entry in _entries) thumb(entry),
        ],
      ),
    );
  }
}

class _ThumbImage extends StatelessWidget {
  const _ThumbImage({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: ClipOval(
        child: AppImage(
          imageUrl: item.image ?? '',
          category: item.category ?? '',
          name: item.name,
          width: _Thumbs.size,
          height: _Thumbs.size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
