import 'package:flutter/material.dart';

import '../core/models/app_update_config.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';

class MandatoryUpdateDialog extends StatefulWidget {
  const MandatoryUpdateDialog({
    required this.requirement,
    required this.onUpdate,
    super.key,
  });

  final AppUpdateRequirement requirement;
  final Future<bool> Function() onUpdate;

  @override
  State<MandatoryUpdateDialog> createState() => _MandatoryUpdateDialogState();
}

class _MandatoryUpdateDialogState extends State<MandatoryUpdateDialog> {
  bool _isOpeningStore = false;
  bool _showLaunchError = false;

  Future<void> _openStore() async {
    if (_isOpeningStore) return;
    setState(() {
      _isOpeningStore = true;
      _showLaunchError = false;
    });

    final opened = await widget.onUpdate();
    if (!mounted) return;
    setState(() {
      _isOpeningStore = false;
      _showLaunchError = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDFA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_alt_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(widget.requirement.title, textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.requirement.message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _VersionLabel(
                            label: l10n.updateCurrentVersion,
                            version: widget.requirement.currentVersion,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.gray400,
                        ),
                        Expanded(
                          child: _VersionLabel(
                            label: l10n.updateLatestVersion,
                            version: widget.requirement.latestVersion,
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showLaunchError) ...[
                    const SizedBox(height: 14),
                    Text(
                      l10n.updateStoreOpenFailed,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isOpeningStore ? null : _openStore,
              icon: _isOpeningStore
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                _isOpeningStore ? l10n.updateOpeningStore : l10n.updateNow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel({
    required this.label,
    required this.version,
    this.alignEnd = false,
  });

  final String label;
  final String version;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(
          version,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: alignEnd ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
