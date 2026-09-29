import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/services/api_client.dart';
import '../core/services/order_export_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_fonts.dart';
import '../l10n/l10n.dart';

class OrderCheckoutActionsSheet {
  static Future<void> handleSuccessfulCheckout({
    required BuildContext context,
    required ApiClient apiClient,
    required dynamic responseData,
  }) async {
    if (usesInAppApprovalFlow(responseData)) {
      await _showAwaitingApproval(context, responseData);
      return;
    }

    final l10n = context.l10n;
    if (kIsWeb) {
      if (!context.mounted) return;
      await showFailure(
        context: context,
        apiClient: apiClient,
        responseData: responseData,
        failureMessage: l10n.checkoutWebSavedMessage,
      );
      return;
    }

    final exportResult = await OrderExportService.downloadOrderReceipt(
      apiClient: apiClient,
      responseData: responseData,
    );
    if (!context.mounted) return;

    final orderFile = exportResult.file;
    if (orderFile == null) {
      await showFailure(
        context: context,
        apiClient: apiClient,
        responseData: responseData,
        // The export service's own messages are English-only.
        failureMessage: l10n.checkoutReceiptPrepareFailed,
      );
      return;
    }

    final shareResult = await OrderExportService.shareOrderReceipt(
      orderFile,
      sharePositionOrigin: _sharePositionOrigin(context),
    );
    if (!context.mounted) return;

    if (shareResult.shareSheetOpened) {
      _showShareSheetOpenedMessage(context);
      return;
    }

    await showFailure(
      context: context,
      apiClient: apiClient,
      responseData: responseData,
      receiptFile: orderFile,
      failureMessage: l10n.checkoutReceiptShareFailed,
    );
  }

  static bool usesInAppApprovalFlow(dynamic responseData) {
    if (responseData is! Map) return false;
    final data = responseData['data'];
    final envelope = data is Map ? data : responseData;
    final nextAction = envelope['nextAction'] ?? responseData['nextAction'];
    final requiresWhatsapp =
        envelope['requiresWhatsapp'] ?? responseData['requiresWhatsapp'];
    return nextAction == 'await_acceptance' && requiresWhatsapp == false;
  }

  static Map<dynamic, dynamic>? _extractOrder(dynamic responseData) {
    if (responseData is! Map) return null;
    final data = responseData['data'];
    final envelope = data is Map ? data : responseData;
    final order = envelope['order'];
    return order is Map ? order : envelope;
  }

  static Future<void> _showAwaitingApproval(
    BuildContext context,
    dynamic responseData,
  ) async {
    final order = _extractOrder(responseData);
    final data = responseData is Map ? responseData['data'] : null;
    final envelope = data is Map ? data : responseData;
    final orderId =
        (order?['id'] ??
                order?['_id'] ??
                (envelope is Map ? envelope['orderId'] : null))
            ?.toString()
            .trim() ??
        '';
    final orderNumber =
        (order?['orderNumber'] ??
                order?['number'] ??
                (envelope is Map ? envelope['orderNumber'] : null))
            ?.toString()
            .trim() ??
        '';

    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF15803D),
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.checkoutOrderSubmitted,
                style: AppFonts.jakarta(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                l10n.checkoutAwaitingApproval,
                style: AppFonts.jakarta(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.checkoutApprovalNote,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 13,
                  height: 1.5,
                  color: const Color(0xFF64748B),
                ),
              ),
              if (orderNumber.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    l10n.orderNumberLabel(orderNumber),
                    style: AppFonts.jakarta(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (orderId.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      context.push('/tracking/$orderId');
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.checkoutViewOrder),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go('/home');
                  },
                  child: Text(l10n.checkoutContinueShopping),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Rect? _sharePositionOrigin(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.localToGlobal(Offset.zero) & renderBox.size;
  }

  static void _showShareSheetOpenedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.checkoutShareSheetOpened,
          style: AppFonts.jakarta(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  static Future<void> showFailure({
    required BuildContext context,
    required ApiClient apiClient,
    required dynamic responseData,
    required String failureMessage,
    File? receiptFile,
  }) async {
    final l10n = context.l10n;
    final orderNumber = OrderExportService.extractOrderNumber(responseData);
    final receiptCaption = OrderExportService.extractCaption(responseData);
    final message = OrderExportService.extractMessage(responseData);
    final orderMessage = [
      // Sent to the shop together with the server's (English) order text.
      if (orderNumber != null && orderNumber.isNotEmpty) 'Order $orderNumber',
      if (message.isNotEmpty) message else receiptCaption,
    ].join('\n\n');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> shareReceipt() async {
          File? file = receiptFile;
          if (file == null || !file.existsSync()) {
            final exportResult = await OrderExportService.downloadOrderReceipt(
              apiClient: apiClient,
              responseData: responseData,
            );
            if (!sheetContext.mounted) return;
            file = exportResult.file;
            if (file == null) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(l10n.checkoutReceiptUnavailableNow),
                  backgroundColor: AppColors.error,
                ),
              );
              return;
            }
          }

          final shareResult = await OrderExportService.shareOrderReceipt(
            file,
            sharePositionOrigin: _sharePositionOrigin(sheetContext),
          );
          if (!sheetContext.mounted) return;
          if (shareResult.shareSheetOpened) {
            Navigator.of(sheetContext).pop();
            _showShareSheetOpenedMessage(context);
            return;
          }

          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(
              content: Text(l10n.checkoutShareOptionsFailed),
              backgroundColor: AppColors.error,
            ),
          );
        }

        Future<void> copyOrderDetails() async {
          await Clipboard.setData(ClipboardData(text: orderMessage));
          if (!sheetContext.mounted) return;
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(content: Text(l10n.checkoutOrderDetailsCopied)),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF0F9D58)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.description_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.checkoutOrderSaved,
                                style: AppFonts.jakarta(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                orderNumber == null || orderNumber.isEmpty
                                    ? l10n.checkoutChooseAnotherWay
                                    : l10n.checkoutOrderSavedChooseAnotherWay(
                                        orderNumber,
                                      ),
                                style: AppFonts.jakarta(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              failureMessage,
                              style: AppFonts.jakarta(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: shareReceipt,
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(
                          l10n.checkoutShareReceipt,
                          style: AppFonts.jakarta(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: copyOrderDetails,
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(
                          l10n.checkoutCopyOrderDetails,
                          style: AppFonts.jakarta(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
