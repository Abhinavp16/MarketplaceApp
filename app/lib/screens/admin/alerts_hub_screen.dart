import 'package:flutter/material.dart';
import '../../core/theme/app_fonts.dart';

class AlertsHubScreen extends StatefulWidget {
  const AlertsHubScreen({super.key});

  @override
  State<AlertsHubScreen> createState() => _AlertsHubScreenState();
}

class _AlertsHubScreenState extends State<AlertsHubScreen> {
  int _selectedTab = 0;
  int _selectedNavIndex = 1;

  // Colors from design
  static const Color primary = Color(0xFF46ec13);
  static const Color backgroundLight = Color(0xFFf6f8f6);
  static const Color textDark = Color(0xFF111b0d);
  static const Color urgent = Color(0xFFff3b30);
  static const Color warning = Color(0xFFffcc00);
  static const Color info = Color(0xFF007aff);
  static const Color gray200 = Color(0xFFe5e7eb);
  static const Color gray400 = Color(0xFF9ca3af);
  static const Color gray600 = Color(0xFF4b5563);
  static const Color gray100 = Color(0xFFf3f4f6);

  final List<String> _tabs = ['All Alerts', 'Pending', 'Payments', 'Inventory'];

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
              child: Column(
                children: [
                  // Top Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 40,
                          child: Icon(Icons.menu, color: textDark),
                        ),
                        Expanded(
                          child: Text(
                            'Alerts Hub',
                            textAlign: TextAlign.center,
                            style: AppFonts.jakarta(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 40,
                          child: Icon(Icons.settings, color: textDark),
                        ),
                      ],
                    ),
                  ),

                  // Tab Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = _selectedTab == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? textDark : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: isSelected
                                    ? null
                                    : Border.all(color: gray200),
                              ),
                              child: Text(
                                _tabs[index],
                                style: AppFonts.jakarta(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected ? Colors.white : textDark,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: gray200),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Alert Card 1 - Urgent
                _buildAlertCard(
                  badgeColor: urgent,
                  badgeText: 'URGENT',
                  time: '2m ago',
                  iconBgColor: primary.withValues(alpha: 0.2),
                  iconColor: primary,
                  icon: Icons.handshake,
                  title: 'New Negotiation Request',
                  description:
                      "AgriCorp is requesting a 15% discount on bulk order for 'Tractor Series X'.",
                  actions: [
                    _ActionButton(
                      text: 'Review Offer',
                      isPrimary: true,
                      primaryColor: primary,
                    ),
                    _ActionButton(text: 'Ignore', isPrimary: false),
                  ],
                ),
                const SizedBox(height: 16),

                // Alert Card 2 - Payment
                _buildAlertCard(
                  badgeColor: info,
                  badgeText: 'PAYMENT VERIFICATION',
                  time: '15m ago',
                  iconBgColor: info.withValues(alpha: 0.1),
                  iconColor: info,
                  icon: Icons.receipt_long,
                  title: 'Payment Screenshot Uploaded',
                  description:
                      'Order #456: GreenField Farms has uploaded proof of payment (\$12,450.00).',
                  linkText: 'TAP TO VERIFY RECEIPT',
                ),
                const SizedBox(height: 16),

                // Alert Card 3 - Inventory
                _buildAlertCard(
                  badgeColor: warning,
                  badgeText: 'INVENTORY ALERT',
                  badgeTextColor: Colors.black,
                  time: '1h ago',
                  iconBgColor: warning.withValues(alpha: 0.2),
                  iconColor: warning,
                  icon: Icons.inventory_2,
                  title: 'Low Stock: Portable Mini Mills',
                  description:
                      'Only 3 units remaining. Restock recommended to fulfill pending pre-orders.',
                  actions: [
                    _ActionButton(
                      text: 'Open Inventory',
                      isPrimary: true,
                      primaryColor: textDark,
                      textColor: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Alert Card 4 - New Member
                _buildAlertCard(
                  badgeColor: gray400,
                  badgeText: 'NEW MEMBER',
                  time: '3h ago',
                  iconBgColor: gray100,
                  iconColor: Color(0xFF6b7280),
                  icon: Icons.person_add,
                  title: 'New Wholesaler Verified',
                  description:
                      'RuralSupply Co. has completed their profile and is now active on the platform.',
                  opacity: 0.8,
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border(top: BorderSide(color: gray200)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  Icons.dashboard,
                  'Home',
                  0,
                  _selectedNavIndex == 0,
                ),
                _buildNavItem(
                  Icons.notifications,
                  'Alerts',
                  1,
                  _selectedNavIndex == 1,
                  hasNotification: true,
                ),
                _buildNavItem(
                  Icons.inventory,
                  'Catalog',
                  2,
                  _selectedNavIndex == 2,
                ),
                _buildNavItem(
                  Icons.analytics,
                  'Reports',
                  3,
                  _selectedNavIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required Color badgeColor,
    required String badgeText,
    Color? badgeTextColor,
    required String time,
    required Color iconBgColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String description,
    List<_ActionButton>? actions,
    String? linkText,
    double opacity = 1.0,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gray200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: AppFonts.jakarta(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: badgeTextColor ?? Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: AppFonts.jakarta(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: gray400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Content Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 16),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          color: gray600,
                          height: 1.4,
                        ),
                      ),

                      // Actions or Link
                      if (actions != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: actions.map((action) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: action != actions.last ? 8 : 0,
                                ),
                                child: SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: action.isPrimary
                                          ? (action.primaryColor ?? primary)
                                          : gray100,
                                      foregroundColor: action.isPrimary
                                          ? (action.textColor ?? textDark)
                                          : textDark,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      action.text,
                                      style: AppFonts.jakarta(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (linkText != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              linkText,
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: primary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 14, color: primary),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    bool isSelected, {
    bool hasNotification = false,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedNavIndex = index),
      child: Opacity(
        opacity: isSelected ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: isSelected ? primary : textDark),
                if (hasNotification)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: urgent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppFonts.jakarta(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected ? primary : textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton {
  final String text;
  final bool isPrimary;
  final Color? primaryColor;
  final Color? textColor;

  _ActionButton({
    required this.text,
    required this.isPrimary,
    this.primaryColor,
    this.textColor,
  });
}
