import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../utils/order_pagination.dart';

final orderCountProvider = FutureProvider<int>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated) return 0;

  try {
    final api = ref.read(apiClientProvider);
    final response = await api.get('/orders');
    if (response.data['success'] == true) {
      final data = response.data['data'] as List<dynamic>? ?? [];
      return resolveOrderTotal(
        Map<String, dynamic>.from(response.data as Map),
        data.length,
      );
    }
  } catch (e) {
    return 0;
  }
  return 0;
});
