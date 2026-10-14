import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/app_image.dart';

import '../../core/providers/wishlist_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/ui/ui.dart';
import '../../l10n/l10n.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistProvider);
    final l10n = context.l10n;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(
          title: l10n.wishlistTitle,
          subtitle: wishlist.items.isNotEmpty
              ? l10n.commonItemsCount(wishlist.items.length)
              : null,
          onBack: () => context.pop(),
          actions: [
            if (wishlist.items.isNotEmpty)
              HeaderIconButton(
                icon: HugeIcons.strokeRoundedDelete02,
                tooltip: l10n.wishlistClearAll,
                color: AppColors.textSecondary,
                onPressed: () => _showClearDialog(context, ref),
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.base),
          switchInCurve: AppMotion.standard,
          switchOutCurve: AppMotion.exit,
          child: wishlist.items.isEmpty
              ? KeyedSubtree(
                  key: const ValueKey('empty'),
                  child: _buildEmptyState(context),
                )
              : ListView.builder(
                  key: const ValueKey('list'),
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: wishlist.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildSwipeHint(context);
                    return _buildWishlistCard(
                      context,
                      ref,
                      wishlist.items[index - 1],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSwipeHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 16,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.wishlistSwipeToRemove,
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: HugeIcons.strokeRoundedFavourite,
      title: context.l10n.wishlistEmptyTitle,
      message: context.l10n.wishlistEmptySubtitle,
    );
  }

  Widget _buildWishlistCard(
    BuildContext context,
    WidgetRef ref,
    WishlistItem item,
  ) {
    final l10n = context.l10n;
    final hasMrp = item.mrp != null && item.mrp! > 0 && item.mrp != item.price;
    final name = pickLocalizedName(context, item.name, item.nameHindi);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(item.productId),
        direction: DismissDirection.endToStart,
        onDismissed: (_) =>
            ref.read(wishlistProvider.notifier).remove(item.productId),
        background: Container(
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedDelete02,
            color: AppColors.error,
            size: 24,
          ),
        ),
        child: Pressable(
          onTap: () => context.push('/product/${item.productId}'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AppColors.surfaceLight,
          semanticLabel: name,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Image
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.gray50,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppImage(
                    imageUrl: item.image ?? '',
                    blurHash: item.blurHash,
                    category: item.category ?? '',
                    name: item.name,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.jakarta(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (item.category != null &&
                          item.category!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.category!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      PriceView(
                        price: item.price,
                        mrp: hasMrp ? item.mrp : null,
                        size: 16,
                        offLabel: (percent) =>
                            l10n.commonPercentOff('$percent'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Remove from the wishlist
                IconButton(
                  tooltip: l10n.uiRemoveFromWishlist,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(wishlistProvider.notifier).remove(item.productId);
                  },
                  style: IconButton.styleFrom(
                    fixedSize: const Size(44, 44),
                    backgroundColor: AppColors.errorSoft,
                  ),
                  icon: const Icon(
                    Icons.favorite_rounded,
                    size: 20,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showClearDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.wishlistClearTitle,
      message: l10n.wishlistClearMessage,
      confirmLabel: l10n.wishlistClearAll,
      cancelLabel: l10n.commonCancel,
      destructive: true,
      icon: HugeIcons.strokeRoundedDelete02,
    );
    if (confirmed) ref.read(wishlistProvider.notifier).clear();
  }
}
