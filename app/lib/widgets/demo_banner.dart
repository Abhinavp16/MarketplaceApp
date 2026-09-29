import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import '../core/config/brand_config.dart';

/// Response of `GET {API_BASE_URL}/demo/info`.
class DemoInfo {
  const DemoInfo({
    required this.demoMode,
    this.brand,
    this.version,
    this.seededAt,
  });

  final bool demoMode;
  final String? brand;
  final String? version;
  final DateTime? seededAt;

  factory DemoInfo.fromJson(Map<String, dynamic> json) {
    return DemoInfo(
      demoMode: json['demoMode'] == true,
      brand: json['brand']?.toString(),
      version: json['version']?.toString(),
      seededAt: DateTime.tryParse(json['seededAt']?.toString() ?? ''),
    );
  }
}

/// Fetches demo metadata from the backend. Resolves to null when the backend is
/// unreachable so the banner falls back to its static text.
final demoInfoProvider = FutureProvider<DemoInfo?>((ref) async {
  if (!ApiConfig.isConfigured) return null;
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    );
    final response = await dio.get('${ApiConfig.baseUrl}/demo/info');
    final body = response.data;
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final data = map['data'];
    return DemoInfo.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : map,
    );
  } catch (_) {
    return null;
  }
});

/// Wraps every route with a persistent "Demonstration Environment" strip.
class DemoBannerShell extends StatelessWidget {
  const DemoBannerShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Column(
      children: [
        const DemoBanner(),
        Expanded(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: 0),
              viewPadding: media.viewPadding.copyWith(top: 0),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class DemoBanner extends ConsumerWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(demoInfoProvider).valueOrNull;
    final topInset = MediaQuery.of(context).padding.top;
    final seeded = info?.seededAt?.toLocal();
    final suffix = seeded == null
        ? ''
        : ' · seeded '
              '${seeded.year.toString().padLeft(4, '0')}-'
              '${seeded.month.toString().padLeft(2, '0')}-'
              '${seeded.day.toString().padLeft(2, '0')}';
    return Material(
      color: const Color(0xFFB45309),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          alignment: Alignment.center,
          child: Text(
            '${BrandConfig.demoBannerText}$suffix',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
