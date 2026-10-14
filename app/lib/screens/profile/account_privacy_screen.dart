import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

class AccountPrivacyScreen extends ConsumerStatefulWidget {
  const AccountPrivacyScreen({super.key});

  @override
  ConsumerState<AccountPrivacyScreen> createState() =>
      _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends ConsumerState<AccountPrivacyScreen> {
  Map<String, dynamic>? _request;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ref
        .read(authProvider.notifier)
        .getAccountDeletionRequest();
    if (!mounted) return;
    setState(() {
      _request = result;
      _error = ref.read(authProvider).error;
      _isLoading = false;
    });
  }

  Future<void> _requestDeletion() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.privacyDialogTitle,
      message: l10n.privacyDialogBody,
      confirmLabel: l10n.privacyRequestDeletion,
      cancelLabel: l10n.privacyKeepAccount,
      destructive: true,
      icon: HugeIcons.strokeRoundedDelete02,
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    final response = await ref
        .read(authProvider.notifier)
        .requestAccountDeletion();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response == null) {
      setState(
        () => _error =
            ref.read(authProvider).error ?? context.l10n.privacySubmitFailed,
      );
      return;
    }
    setState(() => _request = response);
  }

  Future<void> _cancelRequest() async {
    setState(() => _isSubmitting = true);
    final response = await ref
        .read(authProvider.notifier)
        .cancelAccountDeletionRequest();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response == null) {
      setState(
        () => _error =
            ref.read(authProvider).error ?? context.l10n.privacyCancelFailed,
      );
      return;
    }
    setState(() => _request = response);
  }

  String _formatDate(dynamic value) {
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    if (parsed == null) return '—';
    return DateFormat(
      'dd/MM/yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final status = _request?['status']?.toString();
    final canCancel = status == 'pending';
    final rejectionNote = (_request?['staffNote'] ?? '').toString().trim();
    final l10n = context.l10n;

    final Widget body;
    if (_isLoading) {
      body = const _PrivacySkeleton(key: ValueKey('loading'));
    } else {
      body = ListView(
        key: const ValueKey('content'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _InfoCard(
            icon: HugeIcons.strokeRoundedShield01,
            title: l10n.privacyControlsTitle,
            body: l10n.privacyControlsBody(
              'demo.demomart.example/delete-account',
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppFonts.jakarta(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (status == 'pending' || status == 'in_review')
            _RequestStatusCard(
              status: status == 'in_review'
                  ? l10n.privacyStatusUnderReview
                  : l10n.privacyStatusReceived,
              isComplete: false,
              dueDate: _formatDate(_request?['dueAt']),
            )
          else if (status == 'completed')
            _RequestStatusCard(
              status: l10n.privacyStatusCompleted,
              isComplete: true,
              dueDate: _formatDate(_request?['completedAt']),
            )
          else ...[
            // A declined request: say so, with DemoMart's reason, above
            // the option to ask again.
            if (status == 'rejected') ...[
              _InfoCard(
                icon: HugeIcons.strokeRoundedAlert02,
                title: l10n.privacyRejectedTitle,
                body: rejectionNote.isNotEmpty
                    ? l10n.privacyRejectedReason(rejectionNote)
                    : l10n.privacyRejectedNoReason,
              ),
              const SizedBox(height: 12),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.privacyRequestHeading,
                    style: AppFonts.jakarta(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.privacyRequestBody,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: l10n.privacyRequestButton,
                    icon: HugeIcons.strokeRoundedDelete02,
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.medium,
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _requestDeletion,
                  ),
                ],
              ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 12),
            AppButton(
              label: l10n.privacyCancelPending,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _cancelRequest,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.privacyAfterDeletionTitle,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.privacyAfterDeletionBody,
            style: AppFonts.jakarta(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: l10n.privacyTitle),
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.base),
        child: body,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: AppColors.primaryDeep,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.jakarta(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
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

class _RequestStatusCard extends StatelessWidget {
  final String status;
  final bool isComplete;
  final String dueDate;

  const _RequestStatusCard({
    required this.status,
    required this.isComplete,
    required this.dueDate,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(
            label: status,
            tone: isComplete ? ChipTone.success : ChipTone.warning,
            icon: isComplete
                ? HugeIcons.strokeRoundedCheckmarkCircle02
                : HugeIcons.strokeRoundedHourglass,
          ),
          const SizedBox(height: 10),
          Text(
            isComplete
                ? context.l10n.privacyCompletedOn(dueDate)
                : context.l10n.privacyCompleteBy(dueDate),
            style: AppText.price(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySkeleton extends StatelessWidget {
  const _PrivacySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SkeletonShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 96, radius: AppRadius.lg),
            SizedBox(height: 16),
            Skeleton(height: 170, radius: AppRadius.lg),
            SizedBox(height: 24),
            Skeleton(width: 220, height: 16),
            SizedBox(height: 10),
            Skeleton(height: 12),
            SizedBox(height: 6),
            Skeleton(height: 12),
          ],
        ),
      ),
    );
  }
}
