import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/home/marketplace_home_screen.dart';
import '../../screens/home/featured_products_screen.dart';
import '../../screens/categories/categories_screen.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../screens/product/add_product_screen.dart';
import '../../screens/cart/cart_screen.dart';
import '../../screens/cart/buy_now_screen.dart';
import '../../screens/negotiations/negotiations_screen.dart';
import '../../screens/negotiations/negotiation_detail_screen.dart';
import '../../screens/orders/order_success_screen.dart';
import '../../screens/orders/shipment_tracking_screen.dart';
import '../../screens/orders/previous_orders_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/help/help_support_screen.dart';
import '../../screens/help/negotiation_guide_screen.dart';
import '../../screens/notifications/notifications_center_screen.dart';
import '../../screens/wishlist/wishlist_screen.dart';
import '../../screens/profile/account_conversion_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/profile/addresses_screen.dart';
import '../../screens/profile/about_screen.dart';
import '../../screens/profile/legal_policy_screen.dart';
import '../../screens/profile/account_privacy_screen.dart';
import '../../screens/onboarding/permissions_onboarding_screen.dart';
import '../../screens/profile/guest_app_preview_screen.dart';
import '../config/feature_flags.dart';
import '../navigation/app_navigator_key.dart';

final appRouter = GoRouter(
  navigatorKey: appNavigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/permissions-onboarding',
      builder: (context, state) => const PermissionsOnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final initialTab = extra?['tab'] as int?;
        final initialSearchQuery = extra?['searchQuery'] as String?;
        return MarketplaceHomeScreen(
          initialTab: initialTab,
          initialSearchQuery: initialSearchQuery,
        );
      },
    ),
    GoRoute(
      path: '/popular-products',
      builder: (context, state) =>
          const FeaturedProductsScreen(isHotDeals: false),
    ),
    GoRoute(
      path: '/hot-deals',
      builder: (context, state) =>
          const FeaturedProductsScreen(isHotDeals: true),
    ),
    GoRoute(
      path: '/brand/:id',
      builder: (context, state) => CategoriesScreen(
        brandId: state.pathParameters['id'],
        initialCategoryId: state.uri.queryParameters['categoryId'],
        initialCategoryName: state.uri.queryParameters['category'],
        brandName:
            state.uri.queryParameters['name'] ?? state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/product/:id',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ProductDetailScreen(
          productId: state.pathParameters['id'] ?? '',
          heroTag: extra?['heroTag']?.toString(),
        );
      },
    ),
    GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
    GoRoute(
      path: '/negotiations',
      builder: (context, state) => const NegotiationsScreen(),
    ),
    GoRoute(
      path: '/negotiation-detail/:id',
      builder: (context, state) => NegotiationDetailScreen(
        negotiationId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/order-success/:orderId',
      builder: (context, state) =>
          OrderSuccessScreen(orderId: state.pathParameters['orderId'] ?? ''),
    ),
    GoRoute(
      path: '/tracking/:orderId',
      builder: (context, state) => ShipmentTrackingScreen(
        orderId: state.pathParameters['orderId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpSupportScreen(),
    ),
    GoRoute(
      path: '/add-product',
      builder: (context, state) => const AddProductScreen(),
    ),
    GoRoute(
      path: '/buy-now',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return BuyNowScreen(
          productId: extra?['productId'] ?? '',
          productName: extra?['productName'] ?? '',
          productImage: extra?['productImage'],
          price: (extra?['price'] ?? 0).toDouble(),
          mrp: extra?['mrp']?.toDouble(),
          quantity: extra?['quantity'] ?? 1,
          stock: extra?['stock'] ?? 99,
        );
      },
    ),
    GoRoute(
      path: '/previous-orders',
      builder: (context, state) => const PreviousOrdersScreen(),
    ),
    GoRoute(
      path: '/negotiation-guide',
      builder: (context, state) => const NegotiationGuideScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final initialTab = extra?['bottomTab'] as int? ?? 4;
        return NotificationsCenterScreen(initialTab: initialTab);
      },
    ),
    GoRoute(
      path: '/wishlist',
      builder: (context, state) => const WishlistScreen(),
    ),
    GoRoute(
      path: '/convert-to-wholesaler',
      builder: (context, state) => const AccountConversionScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/addresses',
      builder: (context, state) => const AddressesScreen(),
    ),
    GoRoute(
      path: '/account-privacy',
      builder: (context, state) => const AccountPrivacyScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/my-coupons',
      redirect: (context, state) => kHideOfferCouponUi ? '/home' : null,
    ),
    GoRoute(
      path: '/legal/:policyId',
      builder: (context, state) =>
          LegalPolicyScreen(policyId: state.pathParameters['policyId'] ?? ''),
    ),
    GoRoute(
      path: '/guest-app-preview',
      builder: (context, state) => const GuestAppPreviewScreen(),
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Page not found: ${state.error}'))),
);
