import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../app_image.dart';
import '../coming_soon_badge.dart';
import 'pressable.dart';
import 'ui_basics.dart';

/// The app's single product card, used in grids and horizontal rails.
///
/// Give it a bounded height (grid extent or a sized rail); price and [action]
/// sit at the bottom so cards in a row line up.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.onTap,
    this.imageUrl,
    this.category = '',
    this.brand,
    this.mrp,
    this.unit,
    this.packNote,
    this.packPrice,
    this.rating,
    this.reviewCount,
    this.badge,
    this.badgeTone = ChipTone.brand,
    this.inStock = true,
    this.soldOutLabel,
    this.wishlisted,
    this.onWishlist,
    this.wishlistLabel,
    this.action,
    this.heroTag,
    this.specs = const [],
    this.extra,
    this.offLabel,
    this.semanticLabel,
    this.comingSoon = false,
    this.comingSoonPrice,
  });

  final String name;
  final num price;
  final VoidCallback onTap;
  final String? imageUrl;
  final String category;
  final String? brand;
  final num? mrp;

  /// Price suffix, e.g. "/m".
  final String? unit;

  /// One short line under the price, e.g. "Coil 500 m = ₹37,500".
  final String? packNote;

  /// One pack's price ("₹26,000"), shown in bold after [packNote]; it never
  /// gets cut off (the note shortens instead).
  final String? packPrice;

  /// Shown only when not null and above zero.
  final double? rating;
  final int? reviewCount;
  final String? badge;
  final ChipTone badgeTone;
  final bool inStock;
  final String? soldOutLabel;
  final bool? wishlisted;
  final VoidCallback? onWishlist;
  final String? wishlistLabel;

  /// Usually a [QuantityStepper]; laid out full width at the bottom.
  final Widget? action;
  final String? heroTag;
  final List<String> specs;

  /// Any extra line (e.g. a sold-count line) above the price.
  final Widget? extra;
  final String Function(int percent)? offLabel;
  final String? semanticLabel;

  /// Coming Soon (set by the admin): a "Coming Soon" badge in place of any
  /// other tag, no sold-out veil and no add button; it isn't for sale yet.
  final bool comingSoon;

  /// Shown instead of the price when the admin hid it ("Price coming soon").
  final String? comingSoonPrice;

  @override
  Widget build(BuildContext context) {
    // A discount goes on the photo ("16% OFF") unless the caller set a badge,
    // so the price row always fits on one line.
    final m = mrp;
    final percent = m != null && m > 0 && m > price
        ? (((m - price) / m) * 100).round()
        : 0;
    final tag =
        badge ?? (percent > 0 && offLabel != null ? offLabel!(percent) : null);
    final tagTone = badge != null ? badgeTone : ChipTone.success;
    Widget image = Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(10),
      // Rounded corners on the photo itself, inside the grey tile.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: (imageUrl == null || imageUrl!.isEmpty)
            ? AppImage(imageUrl: '', category: category, name: name)
            : AppImage(
                imageUrl: imageUrl!,
                category: category,
                name: name,
                fit: BoxFit.contain,
              ),
      ),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, transitionOnUserGestures: true, child: image);
    }

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      color: AppColors.surfaceLight,
      semanticLabel: semanticLabel ?? name,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (!inStock && !comingSoon)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: StatusChip(
                        label: soldOutLabel ?? 'Sold out',
                        tone: ChipTone.neutral,
                        dense: true,
                      ),
                    ),
                  if (comingSoon)
                    const Positioned(
                      left: 6,
                      top: 6,
                      child: ComingSoonBadge(compact: true),
                    )
                  else if (tag != null && tag.isNotEmpty)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: StatusChip(label: tag, tone: tagTone, dense: true),
                    ),
                  if (onWishlist != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: WishlistButton(
                        active: wishlisted ?? false,
                        onTap: onWishlist!,
                        label: wishlistLabel,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (brand != null && brand!.isNotEmpty)
                      Text(
                        brand!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (specs.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _SpecLine(specs: specs),
                    ],
                    if ((rating ?? 0) > 0) ...[
                      const SizedBox(height: 4),
                      _RatingLine(rating: rating!, count: reviewCount),
                    ],
                    if (extra != null) ...[const SizedBox(height: 4), extra!],
                    const Spacer(),
                    if (comingSoonPrice != null)
                      Text(
                        comingSoonPrice!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: comingSoonColor,
                        ),
                      )
                    else ...[
                      PriceView(
                        price: price,
                        mrp: mrp,
                        unit: unit,
                        size: 15,
                        wrap: false,
                      ),
                      if (packNote != null && packNote!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _PackLine(note: packNote!, price: packPrice),
                        ),
                    ],
                    if (action != null && !comingSoon) ...[
                      const SizedBox(height: 8),
                      PressScaleExclude(child: action!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Bundle 500 m · ₹26,000": the note shortens if space runs out, the
/// bold pack price never does.
class _PackLine extends StatelessWidget {
  const _PackLine({required this.note, this.price});

  final String note;
  final String? price;

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.jakarta(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textTertiary,
    );
    return Row(
      children: [
        Flexible(
          child: Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (price != null) ...[
          Text(' · ', style: style),
          Text(
            price!,
            maxLines: 1,
            style: style.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpecLine extends StatelessWidget {
  const _SpecLine({required this.specs});

  final List<String> specs;

  @override
  Widget build(BuildContext context) {
    return Text(
      specs.where((s) => s.trim().isNotEmpty).join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppFonts.jakarta(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.rating, this.count});

  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: AppFonts.jakarta(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: AppFonts.jakarta(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Heart toggle with a small pop when it becomes active.
class WishlistButton extends StatelessWidget {
  const WishlistButton({
    super.key,
    required this.active,
    required this.onTap,
    this.label,
    this.size = 30,
    this.filledBackground = true,
  });

  final bool active;
  final VoidCallback onTap;
  final String? label;

  /// Diameter of the white circle.
  final double size;
  final bool filledBackground;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.6;
    // The tap area stays at least 44 px even when the circle is small.
    final hitSize = size + 8 < 44 ? 44.0 : size + 8;
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      // Tapping the heart shouldn't shrink the card it sits on.
      child: PressScaleExclude(
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          radius: size * 0.7,
          child: SizedBox(
            width: hitSize,
            height: hitSize,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: filledBackground
                    ? BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.card,
                      )
                    : null,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.base),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: TweenSequence<double>([
                        TweenSequenceItem(
                          tween: Tween(begin: 0.6, end: 1.18),
                          weight: 60,
                        ),
                        TweenSequenceItem(
                          tween: Tween(begin: 1.18, end: 1),
                          weight: 40,
                        ),
                      ]).animate(animation),
                      child: child,
                    ),
                    child: active
                        ? Icon(
                            Icons.favorite_rounded,
                            key: const ValueKey('on'),
                            size: iconSize,
                            color: AppColors.error,
                          )
                        : HugeIcon(
                            key: const ValueKey('off'),
                            icon: HugeIcons.strokeRoundedFavourite,
                            size: iconSize,
                            color: AppColors.textSecondary,
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
}
