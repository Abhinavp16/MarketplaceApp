import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_fonts.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  // Colors from design
  static const Color primary = Color(0xFF46ec13);
  static const Color backgroundLight = Color(0xFFf6f8f6);
  static const Color slate900 = Color(0xFF0f172a);
  static const Color slate400 = Color(0xFF94a3b8);
  static const Color slate200 = Color(0xFFe2e8f0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Column(
        children: [
          // Top Navigation Bar
          Container(
            color: backgroundLight.withOpacity(0.8),
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: slate200)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_ios, color: slate900),
                    const SizedBox(width: 16),
                    Text(
                      'Help & Support',
                      style: AppFonts.jakarta(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: slate900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, how can we help you today?',
                          style: AppFonts.jakarta(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: slate900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: slate200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Icon(Icons.search, color: primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search for help topics...',
                                    hintStyle: AppFonts.jakarta(
                                      color: slate400,
                                      fontSize: 16,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Categories Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Support Categories',
                          style: AppFonts.jakarta(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: slate900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildCategoryCard(Icons.handshake, 'Negotiation Guide')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildCategoryCard(Icons.payments, 'Payment & UPI')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildCategoryCard(Icons.local_shipping, 'Order Tracking')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildCategoryCard(Icons.account_circle, 'Account Help')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // FAQ Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Frequently Asked Questions',
                              style: AppFonts.jakarta(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: slate900,
                              ),
                            ),
                            Text(
                              'View all',
                              style: AppFonts.jakarta(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFaqItem('How do I negotiate with a seller?'),
                        const SizedBox(height: 12),
                        _buildFaqItem('Is my UPI payment secure?'),
                        const SizedBox(height: 12),
                        _buildFaqItem('What is the return policy for products?'),
                        const SizedBox(height: 12),
                        _buildFaqItem('Can I change my delivery address?'),
                      ],
                    ),
                  ),

                  // Featured Resource
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: slate900,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Background Image
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Opacity(
                                opacity: 0.4,
                                child: CachedNetworkImage(
                                  imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBKoJBvqt-aGsgX0R-sYX4APy_oDLqb9T8prRcLjTYZURIUdawPAP-gl0tySi9e0xjI464L3HWii8ySlKncYZkhmVNphQRladT04ooII9D6DUZWN_qKPtnpEXxIzSJjK9W2BONarWJkaSg8aOtKsRL7BF8zagPi3_9BhXRPpx1L-CE-J7oF05VN3toITAs_PNv_eTWIy5XL4hR7Blj_SagyjIihJje1uSMIKlxT4_Z_6vYfhvyF9KNU5fxXnbe6GuVyV8J_0uQUPPIl',
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: slate900),
                                  errorWidget: (context, url, error) => Container(color: slate900),
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: AppFonts.jakarta(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: slate900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Safe Trading Guide 2024',
                                  style: AppFonts.jakarta(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Learn how to protect your payments and get the best deals.',
                                  style: AppFonts.jakarta(
                                    fontSize: 14,
                                    color: Color(0xFFe2e8f0),
                                  ),
                                ),
                              ],
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
        ],
      ),

    );
  }

  Widget _buildCategoryCard(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              question,
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: slate900,
              ),
            ),
          ),
          Icon(Icons.expand_more, color: slate400),
        ],
      ),
    );
  }
}
