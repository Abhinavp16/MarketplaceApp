import 'package:flutter/material.dart';

import '../core/theme/app_fonts.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';

/// Placeholder for a product without a usable image: a category icon and
/// label on a quiet grey tile. Shows when image URLs are missing or fail.
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
    return ColoredBox(
      color: AppColors.gray50,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Small tiles (thumbnails) show the icon only.
          final small =
              constraints.maxHeight < 110 || constraints.maxWidth < 90;
          final circle = small
              ? (constraints.biggest.shortestSide * 0.56).clamp(20.0, 48.0)
              : 64.0;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: circle,
                  height: circle,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    config.icon,
                    size: circle * 0.5,
                    color: AppColors.gray400,
                  ),
                ),
                if (!small) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      config.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.jakarta(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
        icon: Icons.agriculture_rounded,
        label: l10n.productPlaceholderTractor,
      );
    } else if (key.contains('drone') ||
        key.contains('uav') ||
        key.contains('aerial')) {
      return _PlaceholderConfig(
        icon: Icons.flight_rounded,
        label: l10n.productPlaceholderDrone,
      );
    } else if (key.contains('seed') ||
        key.contains('tomato') ||
        key.contains('paddy') ||
        key.contains('wheat')) {
      return _PlaceholderConfig(
        icon: Icons.grass_rounded,
        label: l10n.productPlaceholderSeeds,
      );
    } else if (key.contains('fertil') ||
        key.contains('npk') ||
        key.contains('compost') ||
        key.contains('urea')) {
      return _PlaceholderConfig(
        icon: Icons.science_rounded,
        label: l10n.productPlaceholderFertilizer,
      );
    } else if (key.contains('spray') ||
        key.contains('brush') ||
        key.contains('cutter') ||
        key.contains('saw') ||
        key.contains('tool')) {
      return _PlaceholderConfig(
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
        icon: Icons.plumbing_rounded,
        label: l10n.productPlaceholderGiFitting,
      );
    } else if (key.contains('wire') || key.contains('cable')) {
      return _PlaceholderConfig(
        icon: Icons.cable_rounded,
        label: l10n.productPlaceholderWireCable,
      );
    } else if (key.contains('pipe') || key.contains('column')) {
      return _PlaceholderConfig(
        icon: Icons.linear_scale_rounded,
        label: l10n.productPlaceholderPipe,
      );
    } else if (key.contains('jhatka') ||
        key.contains('fencing') ||
        key.contains('insulator') ||
        key.contains('rassi') ||
        key.contains('frp')) {
      return _PlaceholderConfig(
        icon: Icons.fence_rounded,
        label: l10n.productPlaceholderFencing,
      );
    } else if (key.contains('panel') ||
        key.contains('contactor') ||
        key.contains('relay')) {
      return _PlaceholderConfig(
        icon: Icons.electrical_services_rounded,
        label: l10n.productPlaceholderControlPanel,
      );
    } else if (key.contains('starter') || key.contains('oil')) {
      return _PlaceholderConfig(
        icon: Icons.oil_barrel_rounded,
        label: l10n.productPlaceholderStarterOil,
      );
    } else if (key.contains('pump') || key.contains('submersible')) {
      return _PlaceholderConfig(
        icon: Icons.propane_tank_rounded,
        label: l10n.productPlaceholderPumpSet,
      );
    } else if (key.contains('harvest') ||
        key.contains('combine') ||
        key.contains('reaper')) {
      return _PlaceholderConfig(
        icon: Icons.agriculture_rounded,
        label: l10n.productPlaceholderHarvester,
      );
    } else if (key.contains('pesticide') ||
        key.contains('insect') ||
        key.contains('fungic') ||
        key.contains('herbi') ||
        key.contains('bio')) {
      return _PlaceholderConfig(
        icon: Icons.bug_report_rounded,
        label: l10n.productPlaceholderPesticide,
      );
    } else if (key.contains('soil') ||
        key.contains('test') ||
        key.contains('kit') ||
        key.contains('lab')) {
      return _PlaceholderConfig(
        icon: Icons.biotech_rounded,
        label: l10n.productPlaceholderTestingKit,
      );
    } else if (key.contains('rice') ||
        key.contains('mill') ||
        key.contains('process')) {
      return _PlaceholderConfig(
        icon: Icons.factory_rounded,
        label: l10n.productPlaceholderRiceMill,
      );
    }

    // Generic agriculture fallback
    return _PlaceholderConfig(
      icon: Icons.eco_rounded,
      label: category.isNotEmpty ? category : l10n.productPlaceholderProduct,
    );
  }
}

class _PlaceholderConfig {
  final IconData icon;
  final String label;

  const _PlaceholderConfig({required this.icon, required this.label});
}
