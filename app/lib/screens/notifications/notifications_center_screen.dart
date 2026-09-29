import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/notification_navigation_service.dart';
import '../../widgets/notification_countdown_label.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class NotificationsCenterScreen extends ConsumerStatefulWidget {
  const NotificationsCenterScreen({super.key, this.initialTab = 4});

  final int initialTab;

  @override
  ConsumerState<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState
    extends ConsumerState<NotificationsCenterScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  // Colors from design
  static const Color primary = Color(0xFF46ec13);
  static const Color backgroundLight = Color(0xFFf6f8f6);
  static const Color textDark = Color(0xFF111b0d);
  static const Color statusGreen = Color(0xFF22c55e);
  static const Color statusBlue = Color(0xFF3b82f6);
  static const Color statusOrange = Color(0xFFf97316);
  static const Color gray200 = Color(0xFFe5e7eb);
  static const Color gray400 = Color(0xFF9ca3af);
  static const Color gray500 = Color(0xFF6b7280);
  static const Color gray600 = Color(0xFF4b5563);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);

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
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag;
      case 'payment':
        return Icons.verified;
      case 'shipping':
        return Icons.local_shipping;
      case 'negotiation':
        return Icons.handshake;
      case 'promotion':
        return Icons.campaign;
      case 'price_change_campaign_started':
      case 'price_change_campaign_12h':
      case 'price_change_campaign_6h':
      case 'price_change_campaign_20m':
      case 'price_change_campaign_3h':
      case 'price_change_campaign_1h':
      case 'price_change_campaign_5m':
      case 'price_change_campaign_applied':
        return Icons.schedule_rounded;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'order':
        return statusBlue;
      case 'payment':
        return statusGreen;
      case 'shipping':
        return gray600;
      case 'negotiation':
        return const Color(0xFF7C3AED);
      case 'promotion':
        return statusOrange;
      case 'price_change_campaign_started':
      case 'price_change_campaign_12h':
      case 'price_change_campaign_6h':
      case 'price_change_campaign_20m':
      case 'price_change_campaign_3h':
      case 'price_change_campaign_1h':
      case 'price_change_campaign_5m':
      case 'price_change_campaign_applied':
        return const Color(0xFFEA580C);
      case 'system':
        return gray500;
      default:
        return gray600;
    }
  }

  String _formatTime(String? createdAt) {
    final l10n = context.l10n;
    if (createdAt == null) return l10n.notificationsJustNow;

    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return l10n.notificationsJustNow;
      } else if (diff.inMinutes < 60) {
        return l10n.notificationsMinutesAgo('${diff.inMinutes}');
      } else if (diff.inHours < 24) {
        return l10n.notificationsHoursAgo('${diff.inHours}');
      } else if (diff.inDays < 7) {
        return l10n.notificationsDaysAgo('${diff.inDays}');
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return l10n.notificationsJustNow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // Header
          Container(
            color: backgroundLight.withValues(alpha: 0.8),
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: gray200)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: textDark,
                          size: 18,
                        ),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home', extra: {'tab': 4});
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.notificationsTitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                    ),
                    SizedBox(width: 40, height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationItem(notification);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: gray400),
          const SizedBox(height: 16),
          Text(
            context.l10n.notificationsEmptyTitle,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: gray600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.notificationsEmptySubtitle,
            style: AppFonts.jakarta(fontSize: 14, color: gray500),
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
    final createdAt = notification['createdAt']?.toString();
    final rawData = notification['data'];
    final data = rawData is Map
        ? {
            ...rawData.map((key, value) => MapEntry(key.toString(), value)),
            'type': type,
          }
        : {'type': type};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isRead
            ? null
            : Border.all(color: primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            NotificationNavigationService.instance.openFromContext(
              context,
              data,
              isAuthenticated: ref.read(authProvider).isAuthenticated,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getIconColor(type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForType(type),
                    color: _getIconColor(type),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppFonts.jakarta(
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: textDark,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(createdAt),
                            style: AppFonts.jakarta(
                              fontSize: 12,
                              color: gray500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: AppFonts.jakarta(fontSize: 13, color: gray600),
                      ),
                      NotificationCountdownLabel(
                        data: data,
                        color: const Color(0xFFEA580C),
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),
                // Unread indicator
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
