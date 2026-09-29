import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/config/api_config.dart';
import '../../widgets/product_image_placeholder.dart';
import '../../core/theme/app_fonts.dart';

class AppLandingScreen extends ConsumerStatefulWidget {
  const AppLandingScreen({super.key});

  @override
  ConsumerState<AppLandingScreen> createState() => _AppLandingScreenState();
}

class _AppLandingScreenState extends ConsumerState<AppLandingScreen> {
  // Theme Colors based on the shared image
  static const Color primary = Color(0xFF0F766E); // Vibrant Blue
  // static const Color primaryDark = Color(0xFF115E59); // Removed unused field to fix lint
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  final List<Map<String, String>> categories = [
    {
      'name': 'Power Tools',
      'image':
          'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=400&q=80',
    },
    {
      'name': 'Tractors',
      'image':
          'https://images.unsplash.com/photo-1581093588401-fbb62a02f120?auto=format&fit=crop&w=400&q=80',
    },
    {
      'name': 'Seeds',
      'image':
          'https://images.unsplash.com/photo-1464226184884-fa280b87c399?auto=format&fit=crop&w=400&q=80',
    },
    {
      'name': 'Irrigation',
      'image':
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?auto=format&fit=crop&w=400&q=80',
    },
    {
      'name': 'Drones',
      'image':
          'https://images.unsplash.com/photo-1473968512647-3e447244af8f?auto=format&fit=crop&w=400&q=80',
    },
  ];

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
    ),
  );

  List<Map<String, dynamic>> _heroBanners = [];
  List<Map<String, dynamic>> _promoBanners = [];
  List<Map<String, dynamic>> _offers = [];
  bool _isLoadingOffers = true;
  int _currentHeroIndex = 0;
  int _currentPromoIndex = 0;
  final PageController _heroController = PageController();
  final PageController _promoController = PageController();
  Timer? _heroTimer;
  Timer? _promoTimer;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
    _fetchOffers();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _promoTimer?.cancel();
    _heroController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _fetchBanners() async {
    try {
      final response = await _dio.get('/settings/banners');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? {};
        final List<dynamic> heroItems = data['heroBanners'] ?? [];
        final List<dynamic> promoItems = data['promoBanners'] ?? [];

        setState(() {
          _heroBanners = heroItems
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
          _promoBanners = promoItems
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        });
        _startAutoRotate();
      }
    } catch (e) {
      debugPrint('Error fetching banners: $e');
    }
  }

  Future<void> _fetchOffers() async {
    try {
      final response = await _dio.get(
        '/offers',
        queryParameters: {'targetGroup': 'buyer'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> items = response.data['data'] ?? [];
        setState(() {
          _offers = items.map<Map<String, dynamic>>((item) {
            return {
              'title': item['title'] ?? '',
              'discount': item['discountType'] == 'percentage'
                  ? '${item['discountValue']}%'
                  : '₹${item['discountValue']}',
              'type': item['discountType'] ?? 'percentage',
              'code': item['code'] ?? '',
            };
          }).toList();
          _isLoadingOffers = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching offers: $e');
      setState(() => _isLoadingOffers = false);
    }
  }

  void _startAutoRotate() {
    _heroTimer?.cancel();
    _promoTimer?.cancel();

    if (_heroBanners.length > 1) {
      _heroTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_heroController.hasClients) {
          _currentHeroIndex = (_currentHeroIndex + 1) % _heroBanners.length;
          _heroController.animateToPage(
            _currentHeroIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }

    if (_promoBanners.length > 1) {
      _promoTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
        if (_promoController.hasClients) {
          _currentPromoIndex = (_currentPromoIndex + 1) % _promoBanners.length;
          _promoController.animateToPage(
            _currentPromoIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([_fetchBanners(), _fetchOffers()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: primary,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      _buildHeroBanner(),
                      _buildSectionHeader('Exclusive Offers', 'View Deals'),
                      _buildVoucherList(),
                      _buildSectionHeader('Categories', 'See All'),
                      _buildCategoryGrid(),
                      _buildSectionHeader('Top Brands', ''),
                      _buildBrandRow(),
                      _buildSectionHeader('Popular Products', 'View All'),
                      _buildProductGrid(),
                      if (_promoBanners.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildPromoBannerCarousel(),
                      ],
                      const SizedBox(height: 24),
                      _buildTrustSection(),
                      const SizedBox(height: 100), // Bottom padding for nav bar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  HugeIcons.strokeRoundedZap,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'TradeHub Demo',
                style: AppFonts.jakarta(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
            ],
          ),
          Stack(
            children: [
              const Icon(
                HugeIcons.strokeRoundedNotification01,
                color: textDark,
                size: 28,
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              HugeIcons.strokeRoundedSearch01,
              color: textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search products, brands...',
                style: AppFonts.jakarta(
                  color: textMuted,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              HugeIcons.strokeRoundedMic01,
              color: textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    if (_heroBanners.isEmpty) {
      // Return static fallback if no banners fetched yet
      return _buildHeroItem({
        'title': 'Next-Gen\nTractors',
        'subtitle': 'Revolutionizing agriculture with AI power',
        'tag': 'NEW ARRIVAL',
        'imageUrl':
            'https://images.unsplash.com/photo-1581093588401-fbb62a02f120?auto=format&fit=crop&w=1200&q=80',
      });
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PageView.builder(
            controller: _heroController,
            onPageChanged: (index) => setState(() => _currentHeroIndex = index),
            itemCount: _heroBanners.length,
            itemBuilder: (context, index) =>
                _buildHeroItem(_heroBanners[index]),
          ),
        ),
        if (_heroBanners.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _heroBanners.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentHeroIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentHeroIndex == index
                      ? primary
                      : primary.withOpacity(0.2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroItem(Map<String, dynamic> banner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF115E59), Color(0xFF0F766E)],
                ),
              ),
            ),
            CachedNetworkImage(
              imageUrl: banner['imageUrl']?.toString() ?? '',
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.blue.shade100),
              errorWidget: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF115E59), Color(0xFF0F766E)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (banner['tag'] != null &&
                      banner['tag'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        banner['tag'].toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    banner['title']?.toString() ?? '',
                    style: AppFonts.jakarta(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    banner['subtitle']?.toString() ?? '',
                    style: AppFonts.jakarta(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
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

  Widget _buildSectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppFonts.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          if (action.isNotEmpty)
            Text(
              action,
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoucherList() {
    if (_isLoadingOffers) {
      return Container(
        height: 185,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_offers.isEmpty) {
      // Return static items as fallback if no offers available
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, bottom: 8),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildVoucherCard('Irrigation Kits', '20%', [
              const Color(0xFF134E4A),
              const Color(0xFF3B82F6),
            ], HugeIcons.strokeRoundedDroplet),
            _buildVoucherCard('Premium Seeds', '15%', [
              const Color(0xFF065F46),
              const Color(0xFF10B981),
            ], HugeIcons.strokeRoundedLeaf01),
            _buildVoucherCard('Tractor Parts', '10%', [
              const Color(0xFF5B21B6),
              const Color(0xFF8B5CF6),
            ], HugeIcons.strokeRoundedSettings01),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _offers.asMap().entries.map((entry) {
          final index = entry.key;
          final offer = entry.value;

          // Cycle through colors based on index
          final List<List<Color>> colorSets = [
            [const Color(0xFF134E4A), const Color(0xFF3B82F6)],
            [const Color(0xFF065F46), const Color(0xFF10B981)],
            [const Color(0xFF5B21B6), const Color(0xFF8B5CF6)],
            [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
          ];
          final colors = colorSets[index % colorSets.length];

          // Use appropriate icons based on title keywords
          IconData icon = HugeIcons.strokeRoundedTicket01;
          final title = offer['title'].toLowerCase();
          if (title.contains('seed')) icon = HugeIcons.strokeRoundedLeaf01;
          if (title.contains('water') || title.contains('irrigation')) {
            icon = HugeIcons.strokeRoundedDroplet;
          }
          if (title.contains('tool') || title.contains('parts')) {
            icon = HugeIcons.strokeRoundedSettings01;
          }
          if (title.contains('fertilizer')) {
            icon = HugeIcons.strokeRoundedPackage;
          }

          return _buildVoucherCard(
            offer['title'],
            offer['discount'],
            colors,
            icon,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVoucherCard(
    String title,
    String discount,
    List<Color> colors,
    IconData backgroundIcon,
  ) {
    // Fixed pixel heights — avoids Expanded crash inside ClipPath
    const double cardW = 165;
    const double cardH = 235;
    const double dashedH = 10;
    const double topH = cardH * 0.65 - dashedH / 2; // ~147.75
    const double botH = cardH * 0.35 - dashedH / 2; // ~77.25

    return Container(
      width: cardW,
      height: cardH,
      margin: const EdgeInsets.only(right: 18),
      child: Stack(
        children: [
          // Drop shadow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: colors[0].withOpacity(0.55),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),
          // Ticket clip
          ClipPath(
            clipper: const TicketClipper(),
            child: SizedBox(
              width: cardW,
              height: cardH,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── TOP COLORED SECTION ──
                  SizedBox(
                    width: cardW,
                    height: topH,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [colors[1], colors[0]],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Starburst rays
                          Positioned.fill(
                            child: CustomPaint(painter: StarburstPainter()),
                          ),
                          // Faint icon
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Opacity(
                              opacity: 0.18,
                              child: Icon(
                                backgroundIcon,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Title + discount
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: AppFonts.jakarta(
                                    color: Colors.white.withOpacity(0.92),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (discount.contains('₹'))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 5,
                                              right: 2,
                                            ),
                                            child: Text(
                                              '₹',
                                              style:
                                                  AppFonts.jakarta(
                                                    color: Colors.white,
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1.0,
                                                  ),
                                            ),
                                          ),
                                        Text(
                                          discount
                                              .replaceAll('%', '')
                                              .replaceAll('₹', ''),
                                          style: AppFonts.jakarta(
                                            color: Colors.white,
                                            fontSize: 62,
                                            fontWeight: FontWeight.w900,
                                            height: 0.88,
                                            letterSpacing: -2,
                                          ),
                                        ),
                                        if (discount.contains('%'))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 5,
                                            ),
                                            child: Text(
                                              '%',
                                              style:
                                                  AppFonts.jakarta(
                                                    color: Colors.white,
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1.0,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  'OFF',
                                  style: AppFonts.jakarta(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── DASHED SEPARATOR ──
                  SizedBox(
                    height: 10,
                    width: double.infinity,
                    child: ColoredBox(
                      color: Colors.white,
                      child: CustomPaint(painter: DashedLinePainter()),
                    ),
                  ),
                  // ── BOTTOM WHITE SECTION ──
                  SizedBox(
                    width: cardW,
                    height: botH,
                    child: ColoredBox(
                      color: Colors.white,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'REDEEM',
                                  style: AppFonts.jakarta(
                                    color: colors[0],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return _buildCategoryCard(cat['name']!, cat['image']!);
        },
      ),
    );
  }

  Widget _buildCategoryCard(String name, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
                bottom: Radius.circular(20),
              ),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: textMuted,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Row(
        children: ['DJI', 'Kisan Shop', 'Sampoorti', 'Machine Pro'].map((
          brand,
        ) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Text(
              brand,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Static product data for landing screen
  static const List<Map<String, String>> _landingProducts = [
    {
      'name': 'Drip Irrigation Kit',
      'category': 'IRRIGATION',
      'price': '₹2,499',
      'badge': 'SALE',
      'badgeColor': 'sale',
      'rating': '4.6',
    },
    {
      'name': 'Hybrid Tomato Seeds',
      'category': 'SEEDS',
      'price': '₹349',
      'badge': 'SALE',
      'badgeColor': 'sale',
      'rating': '4.8',
    },
    {
      'name': 'Agriculture Drone',
      'category': 'DRONES',
      'price': '₹89,999',
      'badge': 'NEW',
      'badgeColor': 'new',
      'rating': '4.8',
    },
    {
      'name': 'Power Sprayer 16L',
      'category': 'TOOLS',
      'price': '₹3,799',
      'badge': 'NEW',
      'badgeColor': 'new',
      'rating': '4.7',
    },
  ];

  Widget _buildProductGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;
        final gridColumns = isTablet
            ? (constraints.maxWidth >= 1000 ? 4 : 3)
            : 2;

        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isTablet ? 0.72 : 0.55,
          ),
          itemCount: _landingProducts.length,
          itemBuilder: (context, index) {
            return _buildProductCard(index);
          },
        );
      },
    );
  }

  Widget _buildProductCard(int index) {
    final product = _landingProducts[index];
    final badgeColor = product['badgeColor'] == 'hot'
        ? const Color(0xFFEF4444)
        : product['badgeColor'] == 'sale'
        ? const Color(0xFF16A34A)
        : primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Product illustration placeholder (always visible, no network needed)
                  ProductImagePlaceholder(
                    category: product['category'] ?? '',
                    name: product['name'] ?? '',
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product['badge']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product['category']!,
            style: AppFonts.jakarta(
              color: primary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 52,
            child: Text(
              (product['name'] ?? '')
                  .split(' ')
                  .map((word) {
                    if (word.isEmpty) return word;
                    return word[0].toUpperCase() +
                        word.substring(1).toLowerCase();
                  })
                  .join(' '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.jakarta(
                fontWeight: FontWeight.w400,
                fontSize: 12.5,
                color: textDark,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFBBF24),
                size: 13,
              ),
              const SizedBox(width: 3),
              Text(
                product['rating']!,
                style: AppFonts.jakarta(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                product['price']!,
                style: AppFonts.jakarta(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  HugeIcons.strokeRoundedShoppingCart01,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Why Buy From Us?',
            style: AppFonts.jakarta(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildTrustItem(
                HugeIcons.strokeRoundedShield01,
                'Premium Quality',
              ),
              _buildTrustItem(HugeIcons.strokeRoundedZap, 'Bulk Pricing'),
              _buildTrustItem(HugeIcons.strokeRoundedTools, 'Fast Delivery'),
              _buildTrustItem(
                HugeIcons.strokeRoundedCustomerService01,
                '24/7 Support',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: primary, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: const Border(top: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(HugeIcons.strokeRoundedHome01, 'Home', true),
          _buildNavItem(HugeIcons.strokeRoundedMenuSquare, 'Categories', false),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: primary, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: const Icon(
              HugeIcons.strokeRoundedShoppingCart01,
              color: Colors.white,
              size: 28,
            ),
          ),
          _buildNavItem(HugeIcons.strokeRoundedDeliveryBox01, 'Orders', false),
          _buildNavItem(HugeIcons.strokeRoundedUserCircle, 'Profile', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: active ? primary : textMuted, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? primary : textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPromoBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _promoController,
            onPageChanged: (index) =>
                setState(() => _currentPromoIndex = index),
            itemCount: _promoBanners.length,
            itemBuilder: (context, index) {
              final banner = _promoBanners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: banner['imageUrl'] ?? '',
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) => Container(
                          color: primary.withOpacity(0.1),
                          child: const Icon(Icons.image, color: primary),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.black.withOpacity(0.2),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (banner['tag'] != null &&
                                banner['tag'].toString().isNotEmpty)
                              Text(
                                banner['tag'].toString().toUpperCase(),
                                style: AppFonts.jakarta(
                                  color: primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              banner['title'] ?? '',
                              style: AppFonts.jakarta(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              banner['subtitle'] ?? '',
                              style: AppFonts.jakarta(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_promoBanners.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _promoBanners.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPromoIndex == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentPromoIndex == index
                      ? primary
                      : primary.withOpacity(0.2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  const TicketClipper();

  @override
  Path getClip(Size size) {
    const double cornerRadius = 20.0;
    const double cutoutRadius = 13.0;
    final double cutoutY = size.height * 0.65;

    final Path path = Path();

    // Top-left corner
    path.moveTo(cornerRadius, 0);
    // Top edge -> top-right corner
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    // Right side down to cutout
    path.lineTo(size.width, cutoutY - cutoutRadius);
    // Right semicircle cutout (inward)
    path.arcToPoint(
      Offset(size.width, cutoutY + cutoutRadius),
      radius: const Radius.circular(cutoutRadius),
      clockwise: false,
    );
    // Right side down to bottom-right corner
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );
    // Bottom edge → bottom-left corner
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    // Left side up to cutout
    path.lineTo(0, cutoutY + cutoutRadius);
    // Left semicircle cutout (inward)
    path.arcToPoint(
      Offset(0, cutoutY - cutoutRadius),
      radius: const Radius.circular(cutoutRadius),
      clockwise: false,
    );
    // Left side up to top-left corner
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(TicketClipper oldClipper) => false;
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F766E).withOpacity(0.35)
      ..style = PaintingStyle.fill;

    const double dashWidth = 9.0;
    const double dashSpace = 5.0;
    const double dashHeight = 2.5;
    double currentX = 18.0;
    final double centerY = size.height / 2;

    while (currentX < size.width - 18) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          currentX,
          centerY - dashHeight / 2,
          currentX + dashWidth,
          centerY + dashHeight / 2,
          const Radius.circular(2),
        ),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Draws radiating starburst light rays from the top-center,
/// mimicking the bright spotlight / coupon glow effect in Image 2.
class StarburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset source = Offset(size.width / 2, size.height * 0.05);

    // Alternating bright and dim rays for the starburst
    const int totalRays = 28;
    for (int i = 0; i < totalRays; i++) {
      final bool isBright = i % 2 == 0;
      final paint = Paint()
        ..color = Colors.white.withOpacity(isBright ? 0.13 : 0.06)
        ..style = PaintingStyle.fill;

      // Each ray is a thin triangle from source to the edges
      final double halfAngle = math.pi / totalRays;
      final double baseAngle = (math.pi / totalRays) * 2 * i - math.pi / 2;

      // Calculate far points on a large circle
      const double farRadius = 500.0;
      final Offset left = Offset(
        source.dx + farRadius * math.cos(baseAngle - halfAngle),
        source.dy + farRadius * math.sin(baseAngle - halfAngle),
      );
      final Offset right = Offset(
        source.dx + farRadius * math.cos(baseAngle + halfAngle),
        source.dy + farRadius * math.sin(baseAngle + halfAngle),
      );

      final Path rayPath = Path()
        ..moveTo(source.dx, source.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();

      canvas.drawPath(rayPath, paint);
    }

    // Central bright radial glow
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withOpacity(0.28),
              Colors.white.withOpacity(0.0),
            ],
            radius: 0.55,
          ).createShader(
            Rect.fromCenter(
              center: source,
              width: size.width * 1.4,
              height: size.width * 1.4,
            ),
          );
    canvas.drawCircle(source, size.width * 0.7, glowPaint);
  }

  @override
  bool shouldRepaint(StarburstPainter oldDelegate) => false;
}
