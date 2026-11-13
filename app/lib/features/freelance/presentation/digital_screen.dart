import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/presentation/calm_blocks.dart';
import '../application/freelance_providers.dart';
import '../domain/freelance_domain.dart';
import 'freelance_widgets.dart';

/// "Services digitaux": search, the digital categories and the freelancers
/// as register rows.
class DigitalScreen extends ConsumerStatefulWidget {
  const DigitalScreen({super.key});

  @override
  ConsumerState<DigitalScreen> createState() => _DigitalScreenState();
}

class _DigitalScreenState extends ConsumerState<DigitalScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  String _text = '';
  int? _categoryId;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _apply(v));
  }

  void _apply(String v) {
    if (!mounted) return;
    final t = v.trim();
    if (t != _text) setState(() => _text = t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.watch(freelanceRepositoryProvider);
    final categories = ref.watch(digitalCategoriesProvider);
    final query = FreelanceQuery(
      text: _text.isEmpty ? null : _text,
      categoryId: _categoryId,
    );
    final results = ref.watch(freelancerSearchProvider(query));
    final cats = categories.value ?? const <DigitalCategory>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.flTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(digitalCategoriesProvider);
            ref.invalidate(freelancerSearchProvider(query));
          },
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            children: [
              if (repo.isDemo) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppBadge(
                    label: l10n.demoBannerTitle,
                    icon: Icons.science_outlined,
                    tone: BadgeTone.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: l10n.flSearchHint,
                controller: _field,
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _apply(v);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionTitle(title: l10n.flCategories),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  AppChip(
                    label: l10n.flAllCategories,
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                  for (final c in cats)
                    AppChip(
                      label: c.nameFor(locale),
                      selected: _categoryId == c.id,
                      onSelected: (on) =>
                          setState(() => _categoryId = on ? c.id : null),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionTitle(title: l10n.flResultsTitle),
              results.when(
                loading: () => const SkeletonGroup(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(top: AppSpacing.md),
                    child: Column(
                      children: [
                        Skeleton(height: 72),
                        SizedBox(height: AppSpacing.md),
                        Skeleton(height: 72),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsetsDirectional.only(top: AppSpacing.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.flLoadFailed, style: text.bodyMedium),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: l10n.retry,
                          variant: AppButtonVariant.secondary,
                          expand: false,
                          onPressed: () =>
                              ref.invalidate(freelancerSearchProvider(query)),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.flEmptyTitle, style: text.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l10n.flEmptyBody,
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : FreelancerRegister(list: list, categories: cats),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
