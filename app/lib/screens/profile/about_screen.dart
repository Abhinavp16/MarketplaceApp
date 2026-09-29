import 'package:flutter/material.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: Colors.white.withOpacity(0.16),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.aboutBrand,
                  style: AppFonts.jakarta(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.aboutTagline,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.aboutDescription,
            style: AppFonts.jakarta(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.aboutWhatYouCanDo,
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _featureTile(Icons.verified_outlined, l10n.aboutFeatureCatalogue),
          _featureTile(Icons.location_on_outlined, l10n.aboutFeatureDispatch),
          _featureTile(Icons.local_offer_outlined, l10n.aboutFeatureDealerSupport),
          _featureTile(
            Icons.support_agent_outlined,
            l10n.aboutFeatureDirectContact,
          ),
        ],
      ),
    );
  }

  Widget _featureTile(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF0FDFA),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppFonts.jakarta(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
