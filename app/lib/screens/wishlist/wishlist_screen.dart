import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_image.dart';

import '../../core/providers/wishlist_provider.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  static const Color primaryBlue = Color(0xFF0F766E);
  static const Color backgroundWhite = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color redAccent = Color(0xFFEF4444);

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    return NumberFormatter.formatPrice(p);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: backgroundWhite,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 20,
                        color: textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.wishlistTitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (wishlist.items.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showClearDialog(context, ref),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: surfaceWhite,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderLight),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: textMuted,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),
              if (wishlist.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          context.l10n.commonItemsCount(wishlist.items.length),
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (wishlist.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.swipe_left_rounded,
                        size: 14,
                        color: textMuted.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.wishlistSwipeToRemove,
                        style: AppFonts.jakarta(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              // Content
              Expanded(
                child: wishlist.items.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: wishlist.items.length,
                        itemBuilder: (context, index) => _buildWishlistCard(
                          context,
                          ref,
                          wishlist.items[index],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.favorite_outline_rounded,
              size: 36,
              color: redAccent.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.wishlistEmptyTitle,
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.wishlistEmptySubtitle,
            textAlign: TextAlign.center,
            style: AppFonts.jakarta(
              fontSize: 14,
              color: textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(
    BuildContext context,
    WidgetRef ref,
    WishlistItem item,
  ) {
    final hasMrp = item.mrp != null && item.mrp! > 0 && item.mrp != item.price;
    final discount = hasMrp
        ? (((item.mrp! - item.price) / item.mrp!) * 100).round()
        : 0;

    return Dismissible(
      key: Key(item.productId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          ref.read(wishlistProvider.notifier).remove(item.productId),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: GestureDetector(
        onTap: () => context.push('/product/${item.productId}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderLight.withOpacity(0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppImage(
                    imageUrl: item.image ?? '',
                    blurHash: item.blurHash,
                    category: item.category ?? '',
                    name: item.name,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickLocalizedName(context, item.name, item.nameHindi),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.3,
                      ),
                    ),
                    if (item.category != null && item.category!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.category!,
                        style: AppFonts.jakarta(fontSize: 12, color: textMuted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${_formatPrice(item.price)}',
                          style: AppFonts.jakarta(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        if (hasMrp) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${_formatPrice(item.mrp)}',
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              context.l10n.commonPercentOff('$discount'),
                              style: AppFonts.jakarta(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Remove button
              GestureDetector(
                onTap: () =>
                    ref.read(wishlistProvider.notifier).remove(item.productId),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.wishlistClearTitle,
          style: AppFonts.jakarta(fontWeight: FontWeight.w700),
        ),
        content: Text(
          context.l10n.wishlistClearMessage,
          style: AppFonts.jakarta(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(wishlistProvider.notifier).clear();
              Navigator.pop(ctx);
            },
            child: Text(
              context.l10n.wishlistClearAll,
              style: AppFonts.jakarta(color: redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
