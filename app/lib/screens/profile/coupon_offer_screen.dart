import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/services/redeemed_coupon_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_fonts.dart';

class CouponOfferScreen extends ConsumerStatefulWidget {
  const CouponOfferScreen({super.key});

  @override
  ConsumerState<CouponOfferScreen> createState() => _CouponOfferScreenState();
}

class _CouponOfferScreenState extends ConsumerState<CouponOfferScreen> {
  List<RedeemedCoupon> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    final user = ref.read(authProvider).user;
    final userData = await StorageService.getUserData();
    final userKey = user?.id.isNotEmpty == true
        ? user!.id
        : (user?.phone ??
              user?.email ??
              userData?['id']?.toString() ??
              userData?['_id']?.toString() ??
              userData?['phone']?.toString() ??
              userData?['email']?.toString() ??
              'guest');
    final coupons = await RedeemedCouponService.getCoupons(userKey: userKey);
    if (!mounted) return;
    setState(() {
      _coupons = coupons;
      _loading = false;
    });
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$code copied',
          style: AppFonts.jakarta(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Coupon & Offer Code')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
              ),
            ),
            child: Text(
              'Apply coupons during checkout to unlock discounts and bulk offers.',
              style: AppFonts.jakarta(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_coupons.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                'No redeemed coupons yet. Redeem coupons from Home > Exclusive Offers.',
                style: AppFonts.jakarta(fontSize: 14, height: 1.5),
              ),
            )
          else
            ..._coupons.map(
              (coupon) => _couponCard(
                coupon.code,
                coupon.title,
                coupon.rule,
              ),
            ),
        ],
      ),
    );
  }

  Widget _couponCard(String code, String title, String rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D0D0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFEE2E2),
          child: Icon(Icons.local_offer_outlined, color: Color(0xFFDC2626)),
        ),
        title: Text(code, style: AppFonts.jakarta(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '$title\n$rule',
          style: AppFonts.jakarta(fontSize: 12, height: 1.5),
        ),
        trailing: TextButton(
          onPressed: () => _copyCode(code),
          child: const Text('Copy Code'),
        ),
      ),
    );
  }
}
