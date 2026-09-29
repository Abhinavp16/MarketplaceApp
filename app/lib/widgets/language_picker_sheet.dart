import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/providers/locale_provider.dart';
import '../core/theme/app_fonts.dart';
import '../core/theme/app_theme.dart';
import '../l10n/l10n.dart';

/// Bottom sheet to switch the app between English and Hindi. The choice is
/// saved and synced to the account (for notifications).
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(localeProvider).languageCode;
  final picked = await showModalBottomSheet<Locale>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      Widget option(Locale locale, String label) {
        final selected = current == locale.languageCode;
        return ListTile(
          onTap: () => Navigator.of(sheetContext).pop(locale),
          title: Text(
            label,
            style: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: selected
              ? const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  color: AppColors.primary,
                  size: 22,
                )
              : null,
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l10n.languageChooseTitle,
                  style: AppFonts.jakarta(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              option(LocaleNotifier.english, l10n.languageEnglish),
              option(LocaleNotifier.hindi, l10n.languageHindi),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null || picked.languageCode == current) return;
  await ref.read(localeProvider.notifier).setLocale(picked);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(lookupAppLocalizations(picked).languageChanged)),
  );
}
