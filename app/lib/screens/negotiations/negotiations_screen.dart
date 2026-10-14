import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/deal_desk_groups.dart';
import '../../widgets/ui/ui.dart';
import 'deal_desk_widgets.dart';

class NegotiationsScreen extends ConsumerStatefulWidget {
  const NegotiationsScreen({super.key});

  @override
  ConsumerState<NegotiationsScreen> createState() => _NegotiationsScreenState();
}

class _NegotiationsScreenState extends ConsumerState<NegotiationsScreen>
    with WidgetsBindingObserver {
  int _selectedTab = 0;
  // Active / Completed lists side by side: swipe or tap the switch.
  final PageController _pages = PageController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _negotiations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchNegotiations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchNegotiations();
    }
  }

  Future<void> _fetchNegotiations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/negotiations');
      if (!mounted) return;

      final data = response.data;
      if (data['success'] == true) {
        final List items = data['data'] ?? [];
        setState(() {
          _negotiations = items.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              data['message']?.toString() ??
              context.l10n.negotiationsLoadFailed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.negotiationsLoadFailed;
        _isLoading = false;
      });
    }
  }

  // Active until the order is paid (or the deal is declined/expired).
  List<Map<String, dynamic>> get _activeNegotiations => _negotiations
      .where((n) => !DealDeskPresentation.isCompleted(n))
      .toList();

  List<Map<String, dynamic>> get _completedNegotiations =>
      _negotiations.where(DealDeskPresentation.isCompleted).toList();

  List<Map<String, dynamic>> _negotiationsForTab(int tab) {
    if (tab == 0) {
      return DealDeskPresentation.sortNeedsReplyFirst(_activeNegotiations);
    }
    // Completed tab
    return _completedNegotiations;
  }

  String _idOf(Map<String, dynamic> negotiation) =>
      (negotiation['id'] ?? negotiation['_id'] ?? '').toString();

  Future<void> _openDetail(String negotiationId) async {
    final result = await context.push('/negotiation-detail/$negotiationId');
    if (result == true) _fetchNegotiations();
  }

  void _handleAction(Map<String, dynamic> negotiation, DealTileAction action) {
    final negotiationId = _idOf(negotiation);
    switch (action) {
      case DealTileAction.viewOrder:
        final orderId = negotiation['orderId']?.toString();
        if (orderId != null && orderId.isNotEmpty && orderId != 'null') {
          context.push('/tracking/$orderId');
        } else {
          context.push('/previous-orders');
        }
      case DealTileAction.respond:
      case DealTileAction.viewDetails:
        _openDetail(negotiationId);
      case DealTileAction.underReview:
      case DealTileAction.declined:
      case DealTileAction.expired:
        break;
    }
  }

  /// Slides the lists to [tab] (the switch follows them).
  void _showTab(int tab) {
    if (!_pages.hasClients) {
      setState(() => _selectedTab = tab);
      return;
    }
    final duration = AppMotion.of(context, AppMotion.slow);
    if (duration == Duration.zero) {
      _pages.jumpToPage(tab);
    } else {
      _pages.animateToPage(tab, duration: duration, curve: AppMotion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = _activeNegotiations;
    final completed = _completedNegotiations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(title: l10n.negotiationsTitle),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: DealSegmentedControl(
                labels: [
                  l10n.negotiationsTabActive,
                  l10n.negotiationsTabCompleted,
                ],
                counts: _isLoading ? null : [active.length, completed.length],
                selectedIndex: _selectedTab,
                controller: _pages,
                onChanged: _showTab,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = index);
                },
                children: [_buildPage(0), _buildPage(1)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One list: 0 = active (needs-reply first), 1 = completed.
  Widget _buildPage(int tab) {
    final l10n = context.l10n;
    final deals = _negotiationsForTab(tab);
    final duration = AppMotion.of(context, AppMotion.base);

    final Widget content;
    if (_isLoading) {
      content = ListView.separated(
        key: const ValueKey('loading'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const DealInboxSkeleton(),
      );
    } else if (_error != null) {
      content = ListView(
        key: const ValueKey('error'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: HugeIcons.strokeRoundedAlert02,
            tone: ChipTone.error,
            title: _error!,
            actionLabel: l10n.commonRetry,
            onAction: _fetchNegotiations,
          ),
        ],
      );
    } else if (deals.isEmpty) {
      content = ListView(
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: HugeIcons.strokeRoundedAgreement02,
            title: tab == 0
                ? l10n.negotiationsEmptyActive
                : l10n.negotiationsEmptyCompleted,
            message: l10n.negotiationsEmptyHint,
          ),
        ],
      );
    } else {
      final replyCount = tab == 0
          ? deals.where(DealDeskPresentation.needsReply).length
          : 0;
      // Products sent together sit under one requirement header.
      final entries = dealDeskEntries(
        context,
        deals,
        (negotiation) => DealInboxTile(
          negotiation: negotiation,
          orderShortcut: true,
          onTap: () => _openDetail(_idOf(negotiation)),
          onAction: (action) => _handleAction(negotiation, action),
        ),
        color: AppColors.primaryDeep,
        gap: 12,
      );
      final header = replyCount > 0 ? 1 : 0;
      content = ListView.builder(
        key: const ValueKey('list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        itemCount: entries.length + header,
        itemBuilder: (context, index) {
          if (index < header) {
            return Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 12),
              child: Row(
                children: [
                  const DealNeedsReplyDot(size: 8),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.dealNeedsReplyCount(replyCount),
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return entries[index - header];
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchNegotiations,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.exit,
        child: content,
      ),
    );
  }
}
