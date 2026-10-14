import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../widgets/ui/ui.dart';

// Building blocks of the Home tab: the teal header that folds into a search
// bar, the category grid, round brand logos and the trust card.

/// Teal header at the top of Home. Expanded it shows the brand row, a
/// greeting and a headline above the search bar; as the page scrolls it folds
/// down to just the search bar, which stays pinned.
class HomeHeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  HomeHeroHeaderDelegate({
    required this.topInset,
    required this.topRow,
    required this.greeting,
    required this.headline,
    required this.search,
  });

  /// Status bar height; the teal runs up behind it.
  final double topInset;
  final Widget topRow;
  final String greeting;
  final String headline;
  final Widget search;

  static const double searchHeight = 52;
  static const double _collapsedPadding = 10;

  /// Space between the search bar and the header's sides and bottom.
  static const double gutter = 16;

  /// The search bar's corner radius. The header's bottom corners are this
  /// plus [gutter], so the two curves stay parallel (concentric).
  static const double searchRadius = 16;
  static const double _cornerRadius = searchRadius + gutter;

  // 10 top + 44 brand row + 18 + 17 greeting + 4 + 58 headline + 21 + 52
  // search + 16 bottom.
  static const double _expandedBody = 240;

  /// Height of the header once folded down to just the search bar, which
  /// stays pinned over the top of the page.
  static double collapsedHeight(double topInset) =>
      topInset + _collapsedPadding * 2 + searchHeight;

  @override
  double get minExtent => collapsedHeight(topInset);

  @override
  double get maxExtent => topInset + _expandedBody;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final corner = Radius.circular(lerpDouble(_cornerRadius, 0, t)!);
    final introOpacity = (1 - t * 1.7).clamp(0.0, 1.0);
    final bottomPadding = lerpDouble(gutter, _collapsedPadding, t)!;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(bottom: corner),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDeep, AppColors.primary],
          ),
          boxShadow: t >= 1
              ? [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: corner),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DitherGlow(),
              Positioned(
                left: gutter,
                right: gutter,
                top: topInset + 10 - shrinkOffset,
                child: IgnorePointer(
                  ignoring: introOpacity < 0.1,
                  child: Opacity(
                    opacity: introOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 44, child: topRow),
                        const SizedBox(height: 18),
                        Text(
                          greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: gutter,
                right: gutter,
                bottom: bottomPadding,
                height: searchHeight,
                child: search,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(HomeHeroHeaderDelegate oldDelegate) => true;
}

/// Text size factor for budgeting heights: 1.0 up to 1.6.
double homeTextScale(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.6);

/// Height of the Home category rail for [tileWidth]: square art, a 6 px gap
/// and up to two lines of 11.5 px name. Devanagari lines are taller, and both
/// grow with the text size.
double homeCategoryRailHeight(
  double tileWidth, {
  required double textScale,
  required bool hindi,
}) {
  final lineHeight = 11.5 * (hindi ? 1.6 : 1.25);
  return tileWidth + 6 + 2 * lineHeight * textScale + 2;
}

/// Height of a Home product rail card [cardWidth] wide, the same budget as
/// the Popular/Hot Deals pages: card padding and photo, then brand, name,
/// rating, the one-line price and the Add stepper, which grow with the text
/// size; plus the pack line ("Packet 10 pcs · ₹8,000") when any card has one.
/// Rows without an Add stepper (Coming Soon) pass [hasAction] false so the
/// cards don't keep room for a button they never show.
double homeProductRailHeight(
  double cardWidth, {
  required double textScale,
  required bool hasPackNote,
  bool hasAction = true,
}) {
  final text =
      2 +
      16 +
      34 +
      20 +
      38 +
      12 +
      (hasPackNote ? 16 : 0) -
      (hasAction ? 0 : 66);
  return (cardWidth - 12) + 12 + 10 + 42 + text * textScale;
}

/// One square category shortcut in the Home grid: photo on white, name below.
/// With [isAll] it is the last tile that opens every category.
class HomeCategoryTile extends StatelessWidget {
  const HomeCategoryTile({
    super.key,
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.blurHash,
    this.isAll = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? blurHash;
  final bool isAll;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl?.trim() ?? '';
    final Widget art;
    if (isAll) {
      art = const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedDashboardSquare02,
          size: 26,
          color: AppColors.primaryDeep,
        ),
      );
    } else if (image.isNotEmpty) {
      art = AppImage(
        imageUrl: image,
        blurHash: blurHash,
        category: label,
        name: label,
        fit: BoxFit.contain,
      );
    } else {
      // No photo: the category's initials on a soft teal square.
      final initials = label
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .take(2)
          .map((word) => word.characters.first.toUpperCase())
          .join();
      art = DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Text(
            initials.isEmpty ? '•' : initials,
            style: AppFonts.jakarta(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      );
    }
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.95,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      semanticLabel: label,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAll ? AppColors.primarySoft : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: isAll ? null : Border.all(color: AppColors.border),
              ),
              child: art,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.jakarta(
              fontSize: 11.5,
              fontWeight: isAll ? FontWeight.w800 : FontWeight.w600,
              color: isAll ? AppColors.primaryDeep : AppColors.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand logo on a squircle tile with the name underneath, for the Top
/// Brands row.
class HomeBrandAvatar extends StatelessWidget {
  const HomeBrandAvatar({
    super.key,
    required this.name,
    required this.onTap,
    this.logoUrl,
    this.size = 96,
  });

  final String name;
  final VoidCallback onTap;
  final String? logoUrl;
  final double size;

  static const double _radius = AppRadius.xl;
  static const double _rim = 3;

  @override
  Widget build(BuildContext context) {
    final logo = logoUrl?.trim() ?? '';
    final initial = Center(
      child: Text(
        name.trim().isEmpty ? 'B' : name.trim()[0].toUpperCase(),
        style: AppFonts.jakarta(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDeep,
        ),
      ),
    );
    return SizedBox(
      width: size + 12,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.94,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        semanticLabel: name,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              // A thin white rim around the logo.
              padding: const EdgeInsets.all(_rim),
              decoration: ShapeDecoration(
                color: AppColors.surfaceLight,
                shape: AppShapes.squircle(_radius),
                shadows: AppShadows.card,
              ),
              // Concentric with the tile: its radius minus the rim.
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(_radius - _rim),
                child: logo.isEmpty
                    ? ColoredBox(color: AppColors.primarySoft, child: initial)
                    : CachedNetworkImage(
                        imageUrl: ApiConfig.normalizeMediaUrl(logo),
                        fit: BoxFit.contain,
                        fadeInDuration: AppMotion.base,
                        placeholder: (_, _) => const SizedBox.shrink(),
                        errorWidget: (_, _, _) => ColoredBox(
                          color: AppColors.primarySoft,
                          child: initial,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark teal card with a few plain facts about the shop.
class HomeTrustCard extends StatelessWidget {
  const HomeTrustCard({super.key, required this.title, required this.facts});

  final String title;
  final List<(IconData, String)> facts;

  @override
  Widget build(BuildContext context) {
    final deepest = Color.lerp(AppColors.primaryDeep, Colors.black, 0.25)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDeep, deepest],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < facts.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  for (var j = i; j < i + 2; j++) ...[
                    if (j > i) const SizedBox(width: 10),
                    Expanded(
                      child: j < facts.length
                          ? _TrustFact(icon: facts[j].$1, label: facts[j].$2)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrustFact extends StatelessWidget {
  const _TrustFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 18, color: AppColors.primaryGlow),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.jakarta(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
