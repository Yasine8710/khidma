import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/search_providers.dart';
import 'marketplace_failure_view.dart';
import 'professional_card.dart';

/// Basic search: text and an optional category. Filters and sorting come in
/// the next slice.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.categoryId, this.initialText = ''});

  final int? categoryId;
  final String initialText;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  Timer? _debounce;
  late String _text = widget.initialText;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _text = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = (text: _text, categoryId: widget.categoryId);
    final browsing = _text.trim().isEmpty && widget.categoryId == null;
    final results = ref.watch(searchResultsProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.categoryId == null && widget.initialText.isEmpty,
          textInputAction: TextInputAction.search,
          maxLength: 100,
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _changed,
        ),
      ),
      body: SafeArea(
        child: browsing
            ? EmptyState(
                icon: Icons.search_rounded,
                title: l10n.searchStartTitle,
                body: l10n.searchStartBody,
              )
            : results.when(
                loading: () => const _ResultsSkeleton(),
                error: (e, _) => MarketplaceFailureView(
                  error: e,
                  onRetry: () => ref.invalidate(searchResultsProvider(request)),
                ),
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: l10n.searchNoResultsTitle,
                        body: l10n.searchNoResultsBody,
                      )
                    : ListView.separated(
                        padding: const EdgeInsetsDirectional.all(
                          AppSpacing.gutter,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, i) => ProfessionalCard(
                          professional: list[i],
                          onTap: () => context.push(
                            AppRoutes.professionalPath(list[i].id),
                          ),
                        ),
                      ),
              ),
      ),
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonGroup(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.all(AppSpacing.gutter),
      children: [
        for (var i = 0; i < 4; i++) ...[
          const Skeleton(height: 112, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    ),
  );
}
