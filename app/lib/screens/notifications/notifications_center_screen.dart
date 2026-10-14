import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../widgets/notification_countdown_label.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

/// What a notification is about, for its filter chip and icon colour.
enum _NotificationKind { order, deal, offer, other }

_NotificationKind _kindOf(String type) {
  if (type.startsWith('order') ||
      type.startsWith('payment') ||
      type == 'shipping') {
    return _NotificationKind.order;
  }
  if (type.startsWith('negotiation')) return _NotificationKind.deal;
  if (type == 'promotion' ||
      type.startsWith('price_change') ||
      type == 'product_launched' ||
      type == 'new_product') {
    return _NotificationKind.offer;
  }
  return _NotificationKind.other;
}

/// Day groups for the feed.
enum _DayGroup { today, yesterday, earlier }

class NotificationsCenterScreen extends ConsumerStatefulWidget {
  const NotificationsCenterScreen({super.key, this.initialTab = 4});

  final int initialTab;

  @override
  ConsumerState<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

/// The notifications feed: grouped by day (Today, Yesterday, Earlier), with
/// filter chips, a colour per kind, a thin teal bar on unread rows and, where
/// it helps, one action button (Track order, Open deal, Shop now). Opening a
/// notification marks it read; "Mark all read" clears the rest.
class _NotificationsCenterScreenState
    extends ConsumerState<NotificationsCenterScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  /// The selected filter chip; null shows everything.
  _NotificationKind? _filter;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = _notifications.isEmpty;
      _loadFailed = false;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        '/notifications/my',
        queryParameters: {'limit': 120},
      );

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> items = response.data['data'] ?? [];
        setState(() {
          _notifications = items.map<Map<String, dynamic>>((item) {
            return {
              'id': item['_id']?.toString() ?? '',
              'title': item['title']?.toString() ?? '',
              'body': item['body']?.toString() ?? '',
              'type': item['type']?.toString() ?? 'general',
              'isRead': item['isRead'] == true,
              'createdAt': item['createdAt'],
              'data': item['data'],
            };
          }).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = _notifications.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = _notifications.isEmpty;
        });
      }
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => n['isRead'] != true).length;

  int _unreadOf(_NotificationKind kind) => _notifications
      .where(
        (n) =>
            n['isRead'] != true && _kindOf(n['type']?.toString() ?? '') == kind,
      )
      .length;

  /// Marks [ids] read (all of them when null): locally at once, then on the
  /// server. A failed request only logs; the next refresh shows the truth.
  Future<void> _markRead([List<String>? ids]) async {
    final targets = ids?.where((id) => id.isNotEmpty).toList();
    if (targets != null && targets.isEmpty) return;
    setState(() {
      for (final n in _notifications) {
        if (targets == null || targets.contains(n['id'])) n['isRead'] = true;
      }
    });
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/notifications/mark-read',
            data: targets == null ? {} : {'ids': targets},
          );
    } catch (e) {
      debugPrint('Error marking notifications read: $e');
    }
  }

  Map<String, dynamic> _payloadOf(Map<String, dynamic> notification) {
    final type = notification['type']?.toString() ?? 'general';
    final rawData = notification['data'];
    return rawData is Map
        ? {
            ...rawData.map((key, value) => MapEntry(key.toString(), value)),
            'type': type,
          }
        : {'type': type};
  }

  void _open(Map<String, dynamic> notification) {
    if (notification['isRead'] != true) {
      _markRead([notification['id']?.toString() ?? '']);
    }
    NotificationNavigationService.instance.openFromContext(
      context,
      _payloadOf(notification),
      isAuthenticated: ref.read(authProvider).isAuthenticated,
    );
  }

  /// The action button for important notifications (orders and deals),
  /// named after where it leads. Price updates, offers and anything else get
  /// no button; tapping the row still opens wherever they lead, if anywhere.
  String? _actionLabel(Map<String, dynamic> notification) {
    final l10n = context.l10n;
    final kind = _kindOf(notification['type']?.toString() ?? '');
    if (kind != _NotificationKind.order && kind != _NotificationKind.deal) {
      return null;
    }
    final destination = NotificationNavigationService.instance.destinationFor(
      _payloadOf(notification),
    );
    if (destination == null) return null;
    final route = destination.route;
    if (route.startsWith('/tracking/')) {
      // A cancelled or rejected order has nothing to track.
      final text = [
        notification['type'],
        notification['title'],
        (notification['data'] is Map)
            ? (notification['data'] as Map)['status']
            : null,
      ].whereType<Object>().join(' ').toLowerCase();
      final ended = text.contains('cancel') || text.contains('reject');
      return ended
          ? l10n.notificationsActionViewOrder
          : l10n.notificationsActionTrackOrder;
    }
    if (route.startsWith('/negotiation-detail/')) {
      return l10n.notificationsActionOpenDeal;
    }
    if (route == '/previous-orders') return l10n.notificationsActionViewOrders;
    return null;
  }

  DateTime? _dateOf(Map<String, dynamic> notification) {
    final raw = notification['createdAt']?.toString();
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  _DayGroup _groupOf(DateTime? date) {
    if (date == null) return _DayGroup.today;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return _DayGroup.today;
    if (days == 1) return _DayGroup.yesterday;
    return _DayGroup.earlier;
  }

  /// "10m ago" today, the time yesterday, "12 Sep" earlier (with the year
  /// when it isn't this year).
  String _timeLabel(DateTime? date) {
    final l10n = context.l10n;
    if (date == null) return l10n.notificationsJustNow;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final diff = DateTime.now().difference(date);
    switch (_groupOf(date)) {
      case _DayGroup.today:
        if (diff.inMinutes < 1) return l10n.notificationsJustNow;
        if (diff.inMinutes < 60) {
          return l10n.notificationsMinutesAgo('${diff.inMinutes}');
        }
        return l10n.notificationsHoursAgo('${diff.inHours}');
      case _DayGroup.yesterday:
        return DateFormat.jm(locale).format(date);
      case _DayGroup.earlier:
        return date.year == DateTime.now().year
            ? DateFormat.MMMd(locale).format(date)
            : DateFormat.yMMMd(locale).format(date);
    }
  }

  String _groupTitle(_DayGroup group) {
    final l10n = context.l10n;
    return switch (group) {
      _DayGroup.today => l10n.notificationsToday,
      _DayGroup.yesterday => l10n.notificationsYesterday,
      _DayGroup.earlier => l10n.notificationsEarlier,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget content;
    if (_isLoading) {
      content = ListView.separated(
        key: const ValueKey('loading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => const _NotificationSkeleton(),
      );
    } else if (_loadFailed) {
      content = EmptyState(
        key: const ValueKey('error'),
        icon: HugeIcons.strokeRoundedWifiError01,
        tone: ChipTone.error,
        title: l10n.notificationsLoadFailed,
        message: l10n.notificationsLoadFailedHint,
        actionLabel: l10n.commonRetry,
        onAction: _fetchNotifications,
      );
    } else if (_notifications.isEmpty) {
      content = EmptyState(
        key: const ValueKey('empty'),
        icon: HugeIcons.strokeRoundedNotification02,
        tone: ChipTone.neutral,
        title: l10n.notificationsEmptyTitle,
        message: l10n.notificationsEmptySubtitle,
      );
    } else {
      content = KeyedSubtree(key: const ValueKey('list'), child: _buildFeed());
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(
        title: l10n.notificationsTitle,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home', extra: {'tab': 4});
          }
        },
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: () => _markRead(),
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.base),
        child: content,
      ),
    );
  }

  Widget _buildFeed() {
    final l10n = context.l10n;
    final visible = _filter == null
        ? _notifications
        : _notifications
              .where((n) => _kindOf(n['type']?.toString() ?? '') == _filter)
              .toList();

    // Day headings followed by their rows, in the list's (newest-first) order.
    final entries = <Object>[];
    _DayGroup? current;
    for (final n in visible) {
      final group = _groupOf(_dateOf(n));
      if (group != current) {
        entries.add(group);
        current = group;
      }
      entries.add(n);
    }

    // Only kinds that actually have notifications get a chip.
    final kinds =
        [
          _NotificationKind.order,
          _NotificationKind.deal,
          _NotificationKind.offer,
        ].where(
          (k) => _notifications.any(
            (n) => _kindOf(n['type']?.toString() ?? '') == k,
          ),
        );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchNotifications,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (kinds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.notificationsFilterAll,
                      unread: _unreadCount,
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final kind in kinds) ...[
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: switch (kind) {
                          _NotificationKind.order =>
                            l10n.notificationsFilterOrders,
                          _NotificationKind.deal =>
                            l10n.notificationsFilterDeals,
                          _ => l10n.notificationsFilterOffers,
                        },
                        unread: _unreadOf(kind),
                        selected: _filter == kind,
                        onTap: () => setState(() => _filter = kind),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: EmptyState(
                icon: HugeIcons.strokeRoundedNotification02,
                tone: ChipTone.neutral,
                title: l10n.notificationsFilterEmpty,
                compact: true,
              ),
            ),
          for (final entry in entries)
            if (entry is _DayGroup)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                child: Text(
                  _groupTitle(entry).toUpperCase(),
                  style: AppFonts.jakarta(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildNotificationItem(entry as Map<String, dynamic>),
              ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final type = notification['type']?.toString() ?? 'general';
    final isRead = notification['isRead'] == true;
    final title = notification['title']?.toString() ?? '';
    final body = notification['body']?.toString() ?? '';
    final (tint, ink) = _kindColors(_kindOf(type));
    final action = _actionLabel(notification);

    return Pressable(
      onTap: () => _open(notification),
      color: AppColors.surfaceLight,
      scale: 0.985,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      semanticLabel: title,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: tint,
                    shape: AppShapes.squircle(AppRadius.md),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: _getIconForType(type),
                      color: ink,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppFonts.jakarta(
                                fontSize: 14.5,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: isRead
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeLabel(_dateOf(notification)),
                            style: AppFonts.jakarta(
                              fontSize: 11.5,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: isRead
                                  ? AppColors.textTertiary
                                  : AppColors.primaryDeep,
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          body,
                          style: AppFonts.jakarta(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                      NotificationCountdownLabel(
                        data: _payloadOf(notification),
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 10),
                        AppButton(
                          label: action,
                          onPressed: () => _open(notification),
                          size: AppButtonSize.small,
                          // Light teal, so a list of them stays calm.
                          variant: AppButtonVariant.tonal,
                          expand: false,
                          pill: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Unread rows get a thin teal bar down their left edge.
          if (!isRead)
            const Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              child: SizedBox(
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Icon tile colours per kind: orders teal, deals blue, offers marigold,
  /// everything else grey.
  (Color, Color) _kindColors(_NotificationKind kind) => switch (kind) {
    _NotificationKind.order => (AppColors.primaryTint, AppColors.primary),
    _NotificationKind.deal => (
      const Color(0xFFE8EEFB),
      const Color(0xFF3557A8),
    ),
    _NotificationKind.offer => (AppColors.accentSoft, AppColors.accent),
    _NotificationKind.other => (AppColors.gray50, AppColors.textSecondary),
  };

  IconData _getIconForType(String type) {
    switch (type) {
      case 'order':
        return HugeIcons.strokeRoundedShoppingBag01;
      case 'payment':
        return HugeIcons.strokeRoundedCheckmarkBadge01;
      case 'shipping':
        return HugeIcons.strokeRoundedTruckDelivery;
      case 'negotiation':
        return HugeIcons.strokeRoundedAgreement02;
      case 'promotion':
        return HugeIcons.strokeRoundedMegaphone01;
      // A Coming Soon product went on sale.
      case 'product_launched':
      case 'new_product':
        return HugeIcons.strokeRoundedNewReleases;
      case 'system':
        return HugeIcons.strokeRoundedInformationCircle;
    }
    if (type.startsWith('price_change')) return HugeIcons.strokeRoundedClock01;
    if (type.startsWith('negotiation')) {
      return HugeIcons.strokeRoundedAgreement02;
    }
    if (type.startsWith('payment')) {
      return HugeIcons.strokeRoundedCheckmarkBadge01;
    }
    if (type.startsWith('order')) return HugeIcons.strokeRoundedShoppingBag01;
    return HugeIcons.strokeRoundedNotification02;
  }
}

/// A filter chip with an optional red unread count.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.unread,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int unread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      shape: const StadiumBorder(),
      color: selected ? AppColors.primary : AppColors.surfaceLight,
      semanticLabel: unread > 0 ? '$label, $unread' : label,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.base),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: AppFonts.jakarta(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const SkeletonShimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 38, height: 38, radius: AppRadius.md),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14),
                  SizedBox(height: 8),
                  Skeleton(height: 11),
                  SizedBox(height: 6),
                  Skeleton(width: 160, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
