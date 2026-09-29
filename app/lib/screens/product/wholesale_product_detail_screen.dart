import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_fonts.dart';

class WholesaleProductDetailScreen extends StatefulWidget {
  const WholesaleProductDetailScreen({super.key});

  @override
  State<WholesaleProductDetailScreen> createState() =>
      _WholesaleProductDetailScreenState();
}

class _WholesaleProductDetailScreenState
    extends State<WholesaleProductDetailScreen> {
  final int _currentImageIndex = 0;
  bool _descriptionExpanded = true;

  // Colors from design
  static const Color primary = Color(0xFF115E59);
  static const Color secondary = Color(0xFF3b82f6);
  static const Color backgroundLight = Color(0xFFf8fafc);
  static const Color textDark = Color(0xFF1e293b);
  static const Color gray900 = Color(0xFF0f172a);
  static const Color gray700 = Color(0xFF334155);
  static const Color gray600 = Color(0xFF475569);
  static const Color gray500 = Color(0xFF64748b);
  static const Color gray400 = Color(0xFF94a3b8);
  static const Color gray200 = Color(0xFFe2e8f0);
  static const Color gray100 = Color(0xFFf1f5f9);
  static const Color gray50 = Color(0xFFf8fafc);
  static const Color slate50 = Color(0xFFf8fafc);
  static const Color slate100 = Color(0xFFf1f5f9);
  static const Color blue100 = Color(0xFFdbeafe);
  static const Color blue700 = Color(0xFF115E59);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    onPressed: () {},
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: gray700,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    'Wholesale Details',
                    style: AppFonts.jakarta(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: gray900,
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share, color: gray700, size: 24),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.favorite_border,
                        color: gray700,
                        size: 24,
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: gray100),
                  ),
                ),

                // Product Image
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuBY-zk5FiEndc_-knQOpJocZAcvworTwYA780fuc7IJUA41Tcv-jBY3JDWZOAHHWSOR22RTLhbR9zQ-kMmlfosyue4-qz6j5fPnqD-pJLIS2uFn6uSJYjj1nxwryCChmZxVR5TK_6ip-uMgHpCZ3lBhpQ6BkTjyT44jR-Cz06YNAfg43J47CenHeLrjBWFghK65SJx_sRhlfOcHFhMK4mjg3LMI5PKtpJ7zMHiDBKa1bUjTMreaFq1aXO48ToJqwRp-2UEolzahNwA_',
                            fit: BoxFit.contain,
                            placeholder: (context, url) =>
                                Container(color: gray200),
                            errorWidget: (context, url, error) =>
                                Container(color: gray200),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(4, (index) {
                                  return Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: index == _currentImageIndex
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Product Info Section
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: blue100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'TOP RATED',
                                style: AppFonts.jakarta(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: blue700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'WHOLESALE ONLY',
                                style: AppFonts.jakarta(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          'Multi-Crop Power Tiller',
                          style: AppFonts.jakarta(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: gray900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Price
                        Text(
                          'Wholesale Price: Negotiable',
                          style: AppFonts.jakarta(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Minimum Order Quantity: 5 Units',
                          style: AppFonts.jakarta(
                            fontSize: 12,
                            color: gray500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Delivery info and icons
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: gray500,
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.storefront_outlined,
                              size: 14,
                              color: gray500,
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.local_shipping_outlined,
                              size: 14,
                              color: gray500,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delivery within 5 days of Purchase',
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                color: gray500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Key Specifications
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Specifications',
                              style: AppFonts.jakarta(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: gray500,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Column(
                          children: [
                            _buildSpecItem('Engine', '7HP Heavy Duty'),
                            _buildSpecItem('Fuel Type', 'Petrol/Gasoline'),
                            _buildSpecItem('Warranty', '1 Year Limited'),
                            _buildSpecItem('RPM', '3600 RPM Max'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Product Description
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: gray100)),
                    ),
                    child: Column(
                      children: [
                        // Description Header
                        GestureDetector(
                          onTap: () => setState(
                            () => _descriptionExpanded = !_descriptionExpanded,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: gray50)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Product Description',
                                  style: AppFonts.jakarta(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: gray900,
                                  ),
                                ),
                                Icon(
                                  _descriptionExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: gray400,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Description Content
                        if (_descriptionExpanded)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'The Multi-Crop Power Tiller is a robust and versatile machine designed for modern agriculture. Equipped with a heavy-duty 7HP petrol engine, it provides exceptional power-to-weight ratio for tilling, weeding, and soil preparation across diverse terrains.',
                                  style: AppFonts.jakarta(
                                    fontSize: 14,
                                    color: gray600,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildFeatureItem(
                                  'Adjustable tilling width for various crop spacing.',
                                ),
                                _buildFeatureItem(
                                  'Low fuel consumption with high torque output.',
                                ),
                                _buildFeatureItem(
                                  'Ergonomic handles with vibration dampening technology.',
                                ),
                              ],
                            ),
                          ),

                        // Wholesale Logistics
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: gray50)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Wholesale Logistics',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: gray900,
                                ),
                              ),
                              Icon(Icons.expand_more, color: gray400),
                            ],
                          ),
                        ),

                        // Bulk Order Reviews
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: gray50)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bulk Order Reviews',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: gray900,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Color(0xFFfacc15),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '4.9',
                                    style: AppFonts.jakarta(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: gray900,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.expand_more, color: gray400),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              border: const Border(top: BorderSide(color: gray200)),
            ),
            child: Row(
              children: [
                // Expert Help
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat, color: primary, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      'EXPERT HELP',
                      style: AppFonts.jakarta(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Negotiate Button
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: primary.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.handshake, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Initiate Negotiation',
                            style: AppFonts.jakarta(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slate100),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: primary, size: 14),
          const SizedBox(width: 16),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: AppFonts.jakarta(
                  fontSize: 14,
                  color: textDark,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: AppFonts.jakarta(
                      fontWeight: FontWeight.w600,
                      color: gray500,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: AppFonts.jakarta(
                      fontWeight: FontWeight.w700,
                      color: gray900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.jakarta(fontSize: 14, color: gray600),
            ),
          ),
        ],
      ),
    );
  }
}
