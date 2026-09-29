import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_fonts.dart';

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key});

  // Colors from design
  static const Color primary = Color(0xFF0F766E);
  static const Color backgroundLight = Color(0xFFf6f6f8);
  static const Color textDark = Color(0xFF0d121b);
  static const Color textSecondary = Color(0xFF4c669a);
  static const Color gray200 = Color(0xFFe5e7eb);
  static const Color gray100 = Color(0xFFe7ebf3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // TopAppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.close, color: textDark),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: Text(
                        'Order Confirmation',
                        textAlign: TextAlign.center,
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.015 * 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Success Message
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                      child: Column(
                        children: [
                          // Checkmark Circle
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              size: 60,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            'Order Confirmed!',
                            style: AppFonts.jakarta(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                              letterSpacing: -0.015 * 24,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  color: textSecondary,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(text: 'Your order '),
                                  TextSpan(
                                    text: '#AG-88291',
                                    style: AppFonts.jakarta(
                                      fontWeight: FontWeight.w600,
                                      color: primary,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' has been placed successfully. We\'ll notify you when your machinery is on its way.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Track Order Button
                          SizedBox(
                            width: 200,
                            height: 48,
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
                                'Track Order',
                                style: AppFonts.jakarta(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.015 * 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(height: 1, color: gray200),
                    ),

                    // Delivery Address Section Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Delivery Address',
                        style: AppFonts.jakarta(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.015 * 18,
                        ),
                      ),
                    ),

                    // Address ListItem
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.map, color: primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'John Doe',
                                  style: AppFonts.jakarta(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                                Text(
                                  '123 Farm Road, Rural County, ST 54321',
                                  style: AppFonts.jakarta(
                                    fontSize: 14,
                                    color: textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Product Image
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuClTPMiP5zhhnFRTvnLrC7TH_AFB6I1Y_k9HIiYm5yiiIxDzPDjk-DV0W23tL3qltX0lmmgSUSUf5-Ti9JDJGWMUFmHVw1N0rmHF8ZJWlkemNsXAVzkednBhtDgiphSYrB_ZQaGLwJe1jWbFrjQHlYkwla1t3BBQe0DDjKdKIPN0D81g55jdFe5vZa2CL8l250yliuGB0dr9XoBHNQAM7oW0KiklzDadsYUIZOkDmtL6g838Jw_-z67ikMMQCIUwVtAh6jHBzyImFpO',
                              width: double.infinity,
                              height: 160,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 160,
                                color: gray200,
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 160,
                                color: gray200,
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Text(
                                '1x Heavy Duty Tractor (Model 2024)',
                                style: AppFonts.jakarta(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
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

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gray100,
                        foregroundColor: textDark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue Shopping',
                        style: AppFonts.jakarta(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.015 * 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: AppFonts.jakarta(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Need help? '),
                        TextSpan(
                          text: 'Contact Support',
                          style: AppFonts.jakarta(
                            color: primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
