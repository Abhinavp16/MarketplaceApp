import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../utils/order_pagination.dart';

/// First page of the signed-in user's orders (newest first) and how many
/// orders they have in total.
class OrdersSnapshot {
  const OrdersSnapshot({required this.total, required this.orders});

  final int total;
  final List<Map<String, dynamic>> orders;

  static const empty = OrdersSnapshot(total: 0, orders: []);
}

final recentOrdersProvider = FutureProvider<OrdersSnapshot>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return OrdersSnapshot.empty;

  try {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/orders');
    if (response.data['success'] == true) {
      final data = response.data['data'] as List<dynamic>? ?? [];
      final orders = [
        for (final item in data)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
      DateTime? created(Map<String, dynamic> o) =>
          DateTime.tryParse(o['createdAt']?.toString() ?? '');
      orders.sort((a, b) {
        final ca = created(a), cb = created(b);
        if (ca == null || cb == null) return 0;
        return cb.compareTo(ca);
      });
      return OrdersSnapshot(
        total: resolveOrderTotal(
          Map<String, dynamic>.from(response.data as Map),
          data.length,
        ),
        orders: orders,
      );
    }
  } catch (e) {
    return OrdersSnapshot.empty;
  }
  return OrdersSnapshot.empty;
});

final orderCountProvider = FutureProvider<int>((ref) async {
  final snapshot = await ref.watch(recentOrdersProvider.future);
  return snapshot.total;
});
