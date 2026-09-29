/// Helpers for order history pagination.
///
/// The backend clamps `limit` to 50 and returns the authoritative counts in
/// `pagination`, so callers must prefer `pagination.total`/`hasNext` over the
/// length of the current page.
int resolveOrderTotal(Map<String, dynamic> body, int fallbackLength) {
  final pagination = body['pagination'] as Map?;
  final total = (pagination?['total'] as num?)?.toInt();
  return total ?? fallbackLength;
}

bool hasNextOrderPage(Map<String, dynamic> body) {
  final pagination = body['pagination'] as Map?;
  return pagination?['hasNext'] == true;
}
