import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/services/api_client.dart';
import '../core/services/order_export_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_fonts.dart';
import '../l10n/l10n.dart';
import '../screens/orders/order_parts.dart';
import 'ui/ui.dart';

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
    HapticFeedback.mediumImpact();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OrderSuccessBadge(size: 68),
              Text(
                l10n.checkoutOrderSubmitted,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              StatusChip(
                label: l10n.checkoutAwaitingApproval,
                tone: ChipTone.warning,
                icon: HugeIcons.strokeRoundedClock01,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.checkoutApprovalNote,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
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
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    l10n.orderNumberLabel(orderNumber),
                    style: AppText.price(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (orderId.isNotEmpty) ...[
                AppButton(
                  label: l10n.checkoutViewOrder,
                  icon: HugeIcons.strokeRoundedInvoice01,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.push('/tracking/$orderId');
                  },
                ),
                const SizedBox(height: 4),
              ],
              AppButton(
                label: l10n.checkoutContinueShopping,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.medium,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/home');
                },
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
    showAppSnack(
      context,
      context.l10n.checkoutShareSheetOpened,
      tone: SnackTone.success,
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
              showAppSnack(
                sheetContext,
                l10n.checkoutReceiptUnavailableNow,
                tone: SnackTone.error,
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
            if (context.mounted) _showShareSheetOpenedMessage(context);
            return;
          }

          showAppSnack(
            sheetContext,
            l10n.checkoutShareOptionsFailed,
            tone: SnackTone.error,
          );
        }

        Future<void> copyOrderDetails() async {
          await Clipboard.setData(ClipboardData(text: orderMessage));
          if (!sheetContext.mounted) return;
          showAppSnack(
            sheetContext,
            l10n.checkoutOrderDetailsCopied,
            tone: SnackTone.success,
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: const Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedInvoice01,
                            color: AppColors.primary,
                            size: 26,
                          ),
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
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
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
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OrderInfoPanel(
                    message: failureMessage,
                    tone: ChipTone.warning,
                    icon: HugeIcons.strokeRoundedAlert02,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: l10n.checkoutShareReceipt,
                    icon: HugeIcons.strokeRoundedShare08,
                    onPressed: shareReceipt,
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  AppButton(
                    label: l10n.checkoutCopyOrderDetails,
                    icon: HugeIcons.strokeRoundedCopy01,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.medium,
                    onPressed: copyOrderDetails,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
