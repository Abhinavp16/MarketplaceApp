import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config/brand_config.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

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
    const primaryBlue = Color(0xFF0F766E);
    const textPrimary = Color(0xFF1E293B);
    const textSecondary = Color(0xFF64748B);
    const background = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: textPrimary),
        ),
        title: Text(
          context.l10n.shopLocationTitle,
          style: AppFonts.jakarta(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.shopLocationHint,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: Text(
                    _locating ? context.l10n.shopLocationLocating : context.l10n.shopLocationUseCurrent,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Text(
                  _error!,
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                            color: Color(0xFFDC2626),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.shopLocationSelectedCoordinates,
                    style: AppFonts.jakarta(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                    style: AppFonts.jakarta(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          ShopLocationPickerResult(
                            lat: _selectedLocation.latitude,
                            lng: _selectedLocation.longitude,
                            label: widget.initialLabel,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.l10n.shopLocationConfirm,
                        style: AppFonts.jakarta(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

class _LocationError implements Exception {
  const _LocationError(this.message);
  final String message;
}
