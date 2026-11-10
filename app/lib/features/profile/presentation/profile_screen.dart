import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../gallery/gallery_config.dart';
import '../../settings/presentation/language_selector.dart';
import '../../../core/haptics.dart';
import '../../../core/router/app_routes.dart';

/// Settings only for now (language, appearance). Account features arrive in
/// Phase 2.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final mode = ref.watch(themeModeProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.navProfile, style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.chooseLanguage, style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          const LanguageSelector(),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.themeTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {mode},
            onSelectionChanged: (s) {
              AppHaptics.selection();
              ref.read(themeModeProvider.notifier).setMode(s.first);
            },
          ),
          if (kShowGallery) ...[
            const SizedBox(height: AppSpacing.xl),
            // Developer-only entry; not localized on purpose.
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Design gallery'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRoutes.gallery),
            ),
          ],
        ],
      ),
    );
  }
}
