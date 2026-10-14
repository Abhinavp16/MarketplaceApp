import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/models/app_update_config.dart';
import '../core/theme/app_fonts.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';
import 'ui/ui.dart';

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
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedDownload04,
                    color: AppColors.primaryDeep,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.requirement.title,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.requirement.message,
                textAlign: TextAlign.center,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight02,
                      size: 18,
                      color: AppColors.textTertiary,
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
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              AppButton(
                label: _isOpeningStore
                    ? l10n.updateOpeningStore
                    : l10n.updateNow,
                icon: HugeIcons.strokeRoundedLinkSquare02,
                loading: _isOpeningStore,
                onPressed: _openStore,
              ),
            ],
          ),
        ),
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
        Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          version,
          style: AppText.price(
            fontSize: 16,
            color: alignEnd ? AppColors.primaryDeep : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
