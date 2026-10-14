import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/providers/locale_provider.dart';
import '../core/theme/app_fonts.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';
import 'language_wave.dart';
import 'ui/ui.dart';

/// Bottom sheet to switch the app between English and Hindi. The choice is
/// saved and synced to the account (for notifications).
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(localeProvider).languageCode;
  final picked = await showModalBottomSheet<Locale>(
    context: context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      Widget option(Locale locale, String label) {
        final selected = current == locale.languageCode;
        return Semantics(
          selected: selected,
          child: Pressable(
            onTap: () => Navigator.of(sheetContext).pop(locale),
            semanticLabel: label,
            haptic: true,
            scale: 0.98,
            color: selected ? AppColors.primarySoft : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppFonts.jakarta(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primaryDeep
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      color: AppColors.primary,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
                child: Text(
                  l10n.languageChooseTitle,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              option(LocaleNotifier.english, l10n.languageEnglish),
              const SizedBox(height: 10),
              option(LocaleNotifier.hindi, l10n.languageHindi),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null || picked.languageCode == current) return;
  if (!context.mounted) return;
  // Waits for the sheet to close so it isn't in the wave's snapshot.
  await LanguageWave.run(
    context,
    () => ref.read(localeProvider.notifier).setLocale(picked),
    settle: const Duration(milliseconds: 250),
  );
  if (!context.mounted) return;
  showAppSnack(
    context,
    lookupAppLocalizations(picked).languageChanged,
    tone: SnackTone.success,
  );
}
