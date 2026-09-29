import 'package:flutter/material.dart';
import '../../core/theme/app_fonts.dart';

class NegotiationCelebrationScreen extends StatelessWidget {
  const NegotiationCelebrationScreen({super.key});

  // Colors from design
  static const Color primary = Color(0xFF46ec13);
  static const Color backgroundLight = Color(0xFFf6f8f6);
  static const Color textDark = Color(0xFF111b0d);
  static const Color backgroundDark = Color(0xFF142210);

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
                    child: Icon(Icons.arrow_back, color: textDark),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: Text(
                        'Negotiation Status',
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

            // Celebration Visual
            Container(
              width: double.infinity,
              height: 288,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary.withOpacity(0.1),
                    primary.withOpacity(0.3),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Confetti shapes
                  Positioned(
                    top: 40,
                    left: 40,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    right: 40,
                    child: Transform.rotate(
                      angle: 0.785,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 96,
                    right: 80,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Center icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.celebration,
                        size: 80,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
              child: Column(
                children: [
                  Text(
                    'Deal Sealed!',
                    style: AppFonts.jakarta(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 64,
                    height: 4,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),

            // Body Text
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: textDark,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Your offer for the '),
                    TextSpan(
                      text: 'Mahindra 575 DI',
                      style: AppFonts.jakarta(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' has been accepted.'),
                  ],
                ),
              ),
            ),

            // Stats Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Final Price Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FINAL PRICE',
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textDark.withOpacity(0.6),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹4,85,000',
                            style: AppFonts.jakarta(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Savings Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL SAVINGS',
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: backgroundDark,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '₹15,000',
                                style: AppFonts.jakarta(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: backgroundDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.trending_up, color: backgroundDark, size: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: backgroundDark,
                        elevation: 8,
                        shadowColor: primary.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Proceed to Payment',
                            style: AppFonts.jakarta(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.account_balance_wallet),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textDark,
                        side: BorderSide(color: primary.withOpacity(0.3), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Keep Browsing',
                            style: AppFonts.jakarta(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.shopping_basket, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer Note
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Text(
                'Transaction ID: WH-99283-XPL | Prices are inclusive of GST',
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  color: textDark.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
