import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.privacyDialogTitle),
        content: Text(dialogContext.l10n.privacyDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.privacyKeepAccount),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.privacyRequestDeletion),
          ),
        ],
      ),
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
    const primary = Color(0xFF134E4A);
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF475569);
    final status = _request?['status']?.toString();
    final canCancel = status == 'pending';
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.privacyTitle,
          style: AppFonts.jakarta(fontWeight: FontWeight.w700),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(
                  icon: Icons.security_outlined,
                  color: primary,
                  title: l10n.privacyControlsTitle,
                  body: l10n.privacyControlsBody(
                    'demo.tradehub.example/delete-account',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: AppFonts.jakarta(color: const Color(0xFF991B1B)),
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
                  Text(
                    l10n.privacyRequestHeading,
                    style: AppFonts.jakarta(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.privacyRequestBody,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      height: 1.55,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _requestDeletion,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.delete_outline),
                      label: Text(
                        l10n.privacyRequestButton,
                        style: AppFonts.jakarta(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
                if (canCancel) ...[
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : _cancelRequest,
                    child: Text(
                      l10n.privacyCancelPending,
                      style: AppFonts.jakarta(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.privacyAfterDeletionTitle,
                  style: AppFonts.jakarta(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.privacyAfterDeletionBody,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    height: 1.55,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.jakarta(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    height: 1.5,
                    color: const Color(0xFF475569),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFFF0FDF4) : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top_outlined,
                color: isComplete
                    ? const Color(0xFF15803D)
                    : const Color(0xFF115E59),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: AppFonts.jakarta(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isComplete
                ? context.l10n.privacyCompletedOn(dueDate)
                : context.l10n.privacyCompleteBy(dueDate),
            style: AppFonts.jakarta(
              fontSize: 13,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
