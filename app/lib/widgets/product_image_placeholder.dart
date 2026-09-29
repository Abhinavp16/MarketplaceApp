import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// A visually rich product placeholder that renders a category-specific
/// illustration using Flutter Canvas. Shows when image URLs fail to load.
class ProductImagePlaceholder extends StatelessWidget {
  final String category;
  final String name;

  const ProductImagePlaceholder({
    super.key,
    required this.category,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final config = _configFor(context.l10n, category, name);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: config.gradientColors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background dot pattern
          CustomPaint(painter: _DotPatternPainter(config.accentColor)),
          // Centered icon + label
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    config.icon,
                    size: 38,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    config.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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

  _PlaceholderConfig _configFor(
    AppLocalizations l10n,
    String category,
    String name,
  ) {
    final key = '${category.toLowerCase()} ${name.toLowerCase()}';

    if (key.contains('tractor') ||
        key.contains('mahindra') ||
        key.contains('john deere')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF1B4332), const Color(0xFF2D6A4F)],
        accentColor: const Color(0xFF40916C),
        icon: Icons.agriculture_rounded,
        label: l10n.productPlaceholderTractor,
      );
    } else if (key.contains('drone') ||
        key.contains('uav') ||
        key.contains('aerial')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF1E3A5F), const Color(0xFF0F766E)],
        accentColor: const Color(0xFF3B82F6),
        icon: Icons.flight_rounded,
        label: l10n.productPlaceholderDrone,
      );
    } else if (key.contains('seed') ||
        key.contains('tomato') ||
        key.contains('paddy') ||
        key.contains('wheat')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF14532D), const Color(0xFF16A34A)],
        accentColor: const Color(0xFF22C55E),
        icon: Icons.grass_rounded,
        label: l10n.productPlaceholderSeeds,
      );
    } else if (key.contains('fertil') ||
        key.contains('npk') ||
        key.contains('compost') ||
        key.contains('urea')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF78350F), const Color(0xFFD97706)],
        accentColor: const Color(0xFFF59E0B),
        icon: Icons.science_rounded,
        label: l10n.productPlaceholderFertilizer,
      );
    } else if (key.contains('spray') ||
        key.contains('brush') ||
        key.contains('cutter') ||
        key.contains('saw') ||
        key.contains('tool')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF7C2D12), const Color(0xFFEA580C)],
        accentColor: const Color(0xFFF97316),
        icon: Icons.hardware_rounded,
        label: l10n.productPlaceholderFarmTool,
      );
    } else if (key.contains('irrigation') ||
        key.contains('drip') ||
        key.contains('sprinkler') ||
        key.contains('rain gun') ||
        key.contains('raingun') ||
        key.contains('water')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF0C4A6E), const Color(0xFF0284C7)],
        accentColor: const Color(0xFF38BDF8),
        icon: Icons.water_drop_rounded,
        label: l10n.productPlaceholderIrrigation,
      );
    } else if (key.contains('elbow') ||
        key.contains('socket') ||
        key.contains('tee') ||
        key.contains('nipple') ||
        key.contains('union') ||
        key.contains('bend') ||
        key.contains('cross') ||
        key.contains('flange') ||
        key.contains('valve') ||
        key.contains('coupler') ||
        key.contains('reducer') ||
        key.contains('fitting') ||
        key.contains('check nut')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF334155), const Color(0xFF64748B)],
        accentColor: const Color(0xFF94A3B8),
        icon: Icons.plumbing_rounded,
        label: l10n.productPlaceholderGiFitting,
      );
    } else if (key.contains('wire') || key.contains('cable')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF312E81), const Color(0xFF4338CA)],
        accentColor: const Color(0xFF818CF8),
        icon: Icons.cable_rounded,
        label: l10n.productPlaceholderWireCable,
      );
    } else if (key.contains('pipe') || key.contains('column')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF374151), const Color(0xFF6B7280)],
        accentColor: const Color(0xFFD1D5DB),
        icon: Icons.linear_scale_rounded,
        label: l10n.productPlaceholderPipe,
      );
    } else if (key.contains('jhatka') ||
        key.contains('fencing') ||
        key.contains('insulator') ||
        key.contains('rassi') ||
        key.contains('frp')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF78350F), const Color(0xFFB45309)],
        accentColor: const Color(0xFFF59E0B),
        icon: Icons.fence_rounded,
        label: l10n.productPlaceholderFencing,
      );
    } else if (key.contains('panel') ||
        key.contains('contactor') ||
        key.contains('relay')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF111827), const Color(0xFF1F2937)],
        accentColor: const Color(0xFF9CA3AF),
        icon: Icons.electrical_services_rounded,
        label: l10n.productPlaceholderControlPanel,
      );
    } else if (key.contains('starter') || key.contains('oil')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF7C2D12), const Color(0xFFC2410C)],
        accentColor: const Color(0xFFF97316),
        icon: Icons.oil_barrel_rounded,
        label: l10n.productPlaceholderStarterOil,
      );
    } else if (key.contains('pump') || key.contains('submersible')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF14532D), const Color(0xFF15803D)],
        accentColor: const Color(0xFF4ADE80),
        icon: Icons.propane_tank_rounded,
        label: l10n.productPlaceholderPumpSet,
      );
    } else if (key.contains('harvest') ||
        key.contains('combine') ||
        key.contains('reaper')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF78350F), const Color(0xFFA16207)],
        accentColor: const Color(0xFFCA8A04),
        icon: Icons.agriculture_rounded,
        label: l10n.productPlaceholderHarvester,
      );
    } else if (key.contains('pesticide') ||
        key.contains('insect') ||
        key.contains('fungic') ||
        key.contains('herbi') ||
        key.contains('bio')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF4C1D95), const Color(0xFF7C3AED)],
        accentColor: const Color(0xFFA78BFA),
        icon: Icons.bug_report_rounded,
        label: l10n.productPlaceholderPesticide,
      );
    } else if (key.contains('soil') ||
        key.contains('test') ||
        key.contains('kit') ||
        key.contains('lab')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF1C1917), const Color(0xFF78716C)],
        accentColor: const Color(0xFFA8A29E),
        icon: Icons.biotech_rounded,
        label: l10n.productPlaceholderTestingKit,
      );
    } else if (key.contains('rice') ||
        key.contains('mill') ||
        key.contains('process')) {
      return _PlaceholderConfig(
        gradientColors: [const Color(0xFF1E3A8A), const Color(0xFF115E59)],
        accentColor: const Color(0xFF60A5FA),
        icon: Icons.factory_rounded,
        label: l10n.productPlaceholderRiceMill,
      );
    }

    // Generic agriculture fallback
    return _PlaceholderConfig(
      gradientColors: [const Color(0xFF064E3B), const Color(0xFF059669)],
      accentColor: const Color(0xFF34D399),
      icon: Icons.eco_rounded,
      label: category.isNotEmpty ? category : l10n.productPlaceholderProduct,
    );
  }
}

class _PlaceholderConfig {
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;
  final String label;

  const _PlaceholderConfig({
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
    required this.label,
  });
}

class _DotPatternPainter extends CustomPainter {
  final Color color;
  _DotPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const spacing = 18.0;
    const radius = 2.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }

    // Decorative arc
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.15),
        radius: size.width * 0.7,
      ),
      math.pi * 0.5,
      math.pi * 0.8,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
