import 'dart:async';

import 'package:flutter/material.dart';
import '../core/theme/app_fonts.dart';
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
    this.primaryColor = const Color(0xFF0F172A),
    this.accentColor = const Color(0xFFEA580C),
    this.backgroundColor = const Color(0xFFFFF7ED),
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
    return parsed.toStringAsFixed(0);
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: widget.accentColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.priceNoticeChangesSoon,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: widget.primaryColor,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  '₹$currentPrice → ₹$newPrice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: widget.accentColor,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  timerText,
                  style: AppFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: widget.accentColor,
                    height: 1,
                  ),
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
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.backgroundColor, const Color(0xFFFFFBEB)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.accentColor.withValues(alpha: 0.16),
              ),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              size: 19,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.priceNoticeUpcomingChange,
                  style: AppFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: widget.primaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.priceNoticeChangeIn(
                    currentPriceText,
                    newPriceText,
                    timerText,
                  ),
                  style: AppFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.accentColor,
                    height: 1.25,
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
