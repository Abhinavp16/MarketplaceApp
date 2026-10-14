import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api_client.dart';

class OrderExportDownloadResult {
  final File? file;
  final String? errorMessage;
  final String? debugReason;

  const OrderExportDownloadResult({
    this.file,
    this.errorMessage,
    this.debugReason,
  });

  bool get hasFile => file != null;
}

enum OrderReceiptShareStatus { shareSheetOpened, fileMissing, shareUnavailable }

class OrderReceiptShareResult {
  final OrderReceiptShareStatus status;
  final String? errorMessage;
  final String? debugReason;

  const OrderReceiptShareResult({
    required this.status,
    this.errorMessage,
    this.debugReason,
  });

  bool get shareSheetOpened =>
      status == OrderReceiptShareStatus.shareSheetOpened;
}

class OrderExportService {
  static String? extractOrderId(dynamic responseData) {
    if (responseData is! Map) return null;
    final data = responseData['data'];
    if (data is! Map) return null;
    // Checkout responses carry `orderId`; order objects (order history) carry
    // `id` / `_id`.
    final raw = (data['orderId'] ?? data['id'] ?? data['_id'])
        ?.toString()
        .trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Wraps an order object from `GET /orders` in the same envelope a checkout
  /// response has, so order history can reuse the checkout receipt flow
  /// (PDF export + share). Falls back to the standard caption when the order
  /// has none.
  static Map<String, dynamic> receiptResponseFromOrder(
    Map<String, dynamic> order,
  ) {
    String? text(dynamic value) {
      final raw = value?.toString().trim();
      return (raw == null || raw.isEmpty) ? null : raw;
    }

    final orderId = text(order['orderId'] ?? order['id'] ?? order['_id']);
    final caption =
        text(order['whatsappMessage']) ??
        'Hello, please find my order receipt attached.';
    return {
      'success': true,
      'data': {
        ...order,
        'orderId': orderId,
        'orderNumber': text(order['orderNumber']),
        'exportPath':
            text(order['exportPath']) ??
            (orderId == null ? null : '/orders/$orderId/export?format=pdf'),
        'whatsappMessage': caption,
      },
    };
  }

  static String? extractOrderNumber(dynamic responseData) {
    if (responseData is! Map) return null;
    final data = responseData['data'];
    if (data is! Map) return null;
    final raw = data['orderNumber']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  static String? extractExportPath(dynamic responseData) {
    if (responseData is! Map) return null;
    final data = responseData['data'];
    if (data is! Map) return null;
    final raw = data['exportPath']?.toString().trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Order text supplied by the backend (if any).
  static String extractMessage(dynamic responseData) {
    if (responseData is! Map) return '';
    final data = responseData['data'];
    if (data is! Map) return '';
    return data['message']?.toString() ??
        data['whatsappMessage']?.toString() ??
        responseData['message']?.toString() ??
        '';
  }

  static String extractCaption(dynamic responseData) {
    if (responseData is! Map) {
      return 'Hello, please find my order receipt attached.';
    }
    final data = responseData['data'];
    if (data is! Map) {
      return 'Hello, please find my order receipt attached.';
    }
    final caption = data['whatsappMessage']?.toString().trim();
    if (caption != null && caption.isNotEmpty) return caption;
    return 'Hello, please find my order receipt attached.';
  }

  static Future<OrderExportDownloadResult> downloadOrderReceipt({
    required ApiClient apiClient,
    required dynamic responseData,
  }) async {
    try {
      final orderId = extractOrderId(responseData);
      final exportPath =
          extractExportPath(responseData) ??
          (orderId != null ? '/orders/$orderId/export?format=pdf' : null);

      if (orderId == null || exportPath == null) {
        return const OrderExportDownloadResult(
          errorMessage: 'Order receipt is not available for this checkout yet.',
          debugReason: 'Missing orderId or exportPath in checkout response',
        );
      }

      final orderNumber = extractOrderNumber(responseData) ?? orderId;
      final response = await apiClient.getBytes(exportPath);
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return const OrderExportDownloadResult(
          errorMessage: 'Order receipt was generated but came back empty.',
          debugReason: 'Export endpoint returned zero bytes',
        );
      }

      // Receipts live in their own cache folder: it's the only folder the
      // Android file provider may share (see res/xml/file_paths.xml).
      final tempDir = await getTemporaryDirectory();
      final receiptsDir = Directory('${tempDir.path}/receipts');
      await receiptsDir.create(recursive: true);
      final safeOrderNumber = orderNumber
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '-')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final file = File('${receiptsDir.path}/order-$safeOrderNumber.pdf');
      await file.writeAsBytes(bytes, flush: true);

      return OrderExportDownloadResult(file: file);
    } catch (error) {
      debugPrint('[OrderExport] downloadOrderReceipt failed: $error');
      return OrderExportDownloadResult(
        errorMessage: 'We could not generate the order receipt right now.',
        debugReason: error.toString(),
      );
    }
  }

  static Future<OrderReceiptShareResult> shareOrderReceipt(
    File file, {
    Rect? sharePositionOrigin,
  }) async {
    if (!file.existsSync()) {
      return const OrderReceiptShareResult(
        status: OrderReceiptShareStatus.fileMissing,
        errorMessage: 'The exported order receipt is missing on this device.',
        debugReason: 'Local order receipt file not found',
      );
    }

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      if (result.status == ShareResultStatus.unavailable) {
        return const OrderReceiptShareResult(
          status: OrderReceiptShareStatus.shareUnavailable,
          errorMessage:
              'Receipt sharing is not available on this device. You can still copy the order details.',
          debugReason: 'System share sheet unavailable',
        );
      }

      return const OrderReceiptShareResult(
        status: OrderReceiptShareStatus.shareSheetOpened,
      );
    } catch (error) {
      debugPrint('[OrderExport] shareOrderReceipt failed: $error');
      return OrderReceiptShareResult(
        status: OrderReceiptShareStatus.shareUnavailable,
        errorMessage:
            'We saved your order, but could not open the receipt sharing options.',
        debugReason: error.toString(),
      );
    }
  }
}
