import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/theme/app_fonts.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/number_formatter.dart';
import '../l10n/l10n.dart';

class PendingPriceChangeNotice extends StatefulWidget {
  final Map<String, dynamic>? pendingPriceChange;
  final bool compact;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;

  const PendingPriceChangeNotice({
    super.key,
    required this.pendingPriceChange,
    this.compact = false,
    this.primaryColor = AppColors.textPrimary,
    this.accentColor = AppColors.warning,
    this.backgroundColor = AppColors.warningSoft,
  });

  @override
  State<PendingPriceChangeNotice> createState() =>
      _PendingPriceChangeNoticeState();
}

class _PendingPriceChangeNoticeState extends State<PendingPriceChangeNotice> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _refreshRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant PendingPriceChangeNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingPriceChange != widget.pendingPriceChange) {
      _refreshRemaining();
    }
  }

  void _refreshRemaining() {
    final effectiveAtRaw = widget.pendingPriceChange?['effectiveAt']
        ?.toString();
    final effectiveAt = effectiveAtRaw == null
        ? null
        : DateTime.tryParse(effectiveAtRaw)?.toLocal();

    if (effectiveAt == null) {
      if (mounted) {
        setState(() => _remaining = null);
      }
      return;
    }

    final remaining = effectiveAt.difference(DateTime.now());
    if (mounted) {
      setState(
        () => _remaining = remaining.isNegative ? Duration.zero : remaining,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatPrice(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return NumberFormatter.formatPrice(parsed.round());
  }

  String _formatDuration(AppLocalizations l10n, Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return l10n.priceNoticeDurationHoursMinutes(
        '$hours',
        minutes.toString().padLeft(2, '0'),
      );
    }
    return l10n.priceNoticeDurationMinutesSeconds(
      '$minutes',
      seconds.toString().padLeft(2, '0'),
    );
  }

  Widget _buildCompactNotice({
    required String currentPrice,
    required String newPrice,
    required String timerText,
  }) {
    final accent = widget.accentColor;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 13,
                color: accent,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  context.l10n.priceNoticeChangesSoon,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.jakarta(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.primaryColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '₹$currentPrice → ₹$newPrice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.price(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                timerText,
                maxLines: 1,
                style: AppText.price(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.pendingPriceChange;
    final remaining = _remaining;
    if (data == null || remaining == null || remaining == Duration.zero) {
      return const SizedBox.shrink();
    }

    final currentPrice = data['currentPrice'];
    final newPrice = data['newPrice'];
    final timerText = _formatDuration(context.l10n, remaining);
    final currentPriceText = _formatPrice(currentPrice);
    final newPriceText = _formatPrice(newPrice);

    if (widget.compact) {
      return _buildCompactNotice(
        currentPrice: currentPriceText,
        newPrice: newPriceText,
        timerText: timerText,
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedChartIncrease,
            size: 20,
            color: widget.accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.priceNoticeUpcomingChange,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: widget.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.priceNoticeChangeIn(
                    currentPriceText,
                    newPriceText,
                    timerText,
                  ),
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
