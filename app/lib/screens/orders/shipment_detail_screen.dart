import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_fonts.dart';

class ShipmentDetailScreen extends StatelessWidget {
  const ShipmentDetailScreen({super.key});

  // Colors from design
  static const Color primary = Color(0xFF0F766E);
  static const Color backgroundLight = Color(0xFFf6f6f8);
  static const Color textDark = Color(0xFF0d121b);
  static const Color textSecondary = Color(0xFF4c669a);
  static const Color gray100 = Color(0xFFf3f4f6);
  static const Color gray200 = Color(0xFFe5e7eb);
  static const Color gray300 = Color(0xFFd1d5db);
  static const Color gray400 = Color(0xFF9ca3af);
  static const Color gray500 = Color(0xFF6b7280);
  static const Color green500 = Color(0xFF22c55e);
  static const Color contactGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // TopAppBar
          Container(
            color: backgroundLight.withOpacity(0.9),
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.arrow_back_ios, color: textDark),
                    ),
                    Expanded(
                      child: Text(
                        'Shipment Details',
                        textAlign: TextAlign.center,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.015 * 18,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Icon(Icons.more_horiz, color: textDark),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary Card
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gray100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order ID',
                                    style: AppFonts.jakarta(
                                      fontSize: 14,
                                      color: gray500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '#ORD-882910',
                                    style: AppFonts.jakarta(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'IN TRANSIT',
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: gray100),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: backgroundLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.agriculture, color: primary),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Industrial Seed Drill X200',
                                    style: AppFonts.jakarta(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: textDark,
                                    ),
                                  ),
                                  Text(
                                    'Qty: 1 Unit • \$12,450.00',
                                    style: AppFonts.jakarta(
                                      fontSize: 12,
                                      color: gray500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Order Journey Section Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order Journey',
                          style: AppFonts.jakarta(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                            letterSpacing: -0.015 * 18,
                          ),
                        ),
                        Text(
                          'Update Status',
                          style: AppFonts.jakarta(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Timeline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildTimelineItem(
                          icon: Icons.check_circle,
                          iconColor: green500,
                          lineColor: green500,
                          title: 'Payment Verified',
                          subtitle: 'Oct 12, 09:30 AM',
                          isFirst: true,
                          isCompleted: true,
                        ),
                        _buildTimelineItem(
                          icon: Icons.inventory_2,
                          iconColor: green500,
                          lineColor: green500,
                          title: 'Order Packed',
                          subtitle: 'Oct 13, 02:15 PM',
                          isCompleted: true,
                        ),
                        _buildTimelineItem(
                          icon: Icons.local_shipping,
                          iconColor: primary,
                          lineColor: gray300,
                          title: 'Dispatched',
                          subtitle: 'Oct 14, 10:00 AM • Kansas Hub',
                          badge: 'LATEST',
                          isCompleted: true,
                        ),
                        _buildTimelineItem(
                          icon: Icons.near_me,
                          iconColor: gray400,
                          lineColor: gray300,
                          title: 'Out for Delivery',
                          subtitle: 'Expected Oct 16, 2023',
                          isLast: true,
                          isCompleted: false,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Courier Information Section Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Courier Information',
                      style: AppFonts.jakarta(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                        letterSpacing: -0.015 * 18,
                      ),
                    ),
                  ),

                  // Tracking Link Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gray100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.link, color: primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tracking Link',
                                  style: AppFonts.jakarta(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textDark,
                                  ),
                                ),
                                Text(
                                  'track.agri-logistics.com/SHP990123',
                                  style: AppFonts.jakarta(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Copy',
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Buyer Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gray100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buyer: Robert Miller',
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.chat, size: 18),
                                    label: Text(
                                      'Message',
                                      style: AppFonts.jakarta(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: contactGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.call, size: 18),
                                    label: Text(
                                      'Call Buyer',
                                      style: AppFonts.jakarta(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Shipment Map Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'Shipment Map',
                      style: AppFonts.jakarta(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ),

                  // Map
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: gray200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Opacity(
                              opacity: 0.6,
                              child: CachedNetworkImage(
                                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuClwNdKnBECNfPCAO8Bm4l6e3aH0ebvLD4O9400lnwTL_srWThoJdSnuRF1TJh2LR9F2svt08dTLsoeZ0e8ZmXv7BLATOsO2cAPL6JQdBfnlxMuDuwXqLhABekfAaQFiLBB_dKRpXGGVK0UbPHxG7C-Ofj3INQDzoZuZqbj_onyoFZj5nBKkRQydj1E3mL-0JOLvcEn8Uk55oqxpuTFiU6LiJsT7Mo5IGpPwLf1Y3gHl8qtCiPhJizQ8VX8RGzIfB7-PMmpQ8_3e6NM',
                                width: double.infinity,
                                height: 160,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: gray200),
                                errorWidget: (context, url, error) => Container(color: gray200),
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(
                              Icons.location_on,
                              color: primary,
                              size: 48,
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Last sync: 2 mins ago',
                                style: AppFonts.jakarta(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: gray100)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: primary.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Update Status',
                    style: AppFonts.jakarta(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required Color lineColor,
    required String title,
    required String subtitle,
    String? badge,
    bool isFirst = false,
    bool isLast = false,
    bool isCompleted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        SizedBox(
          width: 40,
          child: Column(
            children: [
              if (!isFirst)
                Container(width: 1.5, height: 8, color: lineColor),
              Icon(icon, color: iconColor, size: 24),
              if (!isLast)
                Container(width: 1.5, height: 32, color: lineColor),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppFonts.jakarta(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isCompleted ? textDark : textDark.withOpacity(0.5),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: AppFonts.jakarta(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
