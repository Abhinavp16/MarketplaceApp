import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/config/brand_config.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

class ShopLocationPickerResult {
  final double lat;
  final double lng;
  final String? label;

  const ShopLocationPickerResult({
    required this.lat,
    required this.lng,
    this.label,
  });
}

class ShopLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialLabel;

  const ShopLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialLabel,
  });

  @override
  State<ShopLocationPickerScreen> createState() =>
      _ShopLocationPickerScreenState();
}

class _ShopLocationPickerScreenState extends State<ShopLocationPickerScreen> {
  static const _fallbackLatLng = LatLng(21.2514, 81.6296);

  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedLocation = (widget.initialLat != null && widget.initialLng != null)
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _fallbackLatLng;
  }

  Future<void> _useCurrentLocation() async {
    final l10n = context.l10n;
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw _LocationError(l10n.shopLocationServicesOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw _LocationError(l10n.shopLocationPermissionDenied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _selectedLocation = latLng;
      });
      _mapController.move(latLng, 16);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is _LocationError ? e.message : l10n.shopLocationFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(
        title: l10n.shopLocationTitle,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.shopLocationHint,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: _locating
                      ? l10n.shopLocationLocating
                      : l10n.shopLocationUseCurrent,
                  icon: HugeIcons.strokeRoundedGps01,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.medium,
                  expand: false,
                  loading: _locating,
                  onPressed: _locating ? null : _useCurrentLocation,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.fast),
            alignment: Alignment.topCenter,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedAlert02,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AppFonts.jakarta(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom: widget.initialLat != null ? 16 : 11,
                    onTap: (_, latLng) {
                      setState(() => _selectedLocation = latLng);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: BrandConfig.packageName,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          width: 56,
                          height: 56,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedMapPin,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.shopLocationSelectedCoordinates,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style:
                              AppFonts.jakarta(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: l10n.shopLocationConfirm,
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    onPressed: () {
                      Navigator.of(context).pop(
                        ShopLocationPickerResult(
                          lat: _selectedLocation.latitude,
                          lng: _selectedLocation.longitude,
                          label: widget.initialLabel,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationError implements Exception {
  const _LocationError(this.message);
  final String message;
}
