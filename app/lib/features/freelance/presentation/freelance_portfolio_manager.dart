import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/register_row.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../marketplace/presentation/professional_card.dart';
import '../application/freelance_providers.dart';
import '../domain/freelance_domain.dart';
import 'freelance_widgets.dart';
import 'freelancer_screen.dart' show kindIcon, kindLabel;

/// What the sheet collects before a file is picked or a link is saved.
class _ItemDraft {
  const _ItemDraft(this.title, this.description, this.url);
  final String title;
  final String? description;
  final String? url;
}

/// The owner's portfolio: add photos, short clips, video links and links;
/// edit title and description; delete. At most 24 items.
class FreelancePortfolioManager extends ConsumerWidget {
  const FreelancePortfolioManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(freelanceActionsProvider);
    final async = ref.watch(myFreelancePortfolioProvider);
    final items = async.value ?? const <FreelancePortfolioItem>[];
    final full = items.length >= FreelanceRules.maxPortfolioItems;

    Widget add(String label, IconData icon, PortfolioKind kind) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: AppButton(
        label: busy ? l10n.flUploading : label,
        icon: icon,
        variant: AppButtonVariant.secondary,
        isLoading: busy,
        onPressed: full || async.isLoading
            ? null
            : () => _add(context, ref, kind),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RegisterHeading(title: l10n.flPortfolio),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.flPortCount(items.length, FreelanceRules.maxPortfolioItems),
            style: text.titleSmall,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (async.isLoading && items.isEmpty)
          const SkeletonGroup(child: Skeleton(height: 56))
        else if (async.hasError && items.isEmpty)
          Text(l10n.flErrGeneric, style: text.bodyMedium)
        else if (items.isEmpty)
          Text(l10n.flPortEmpty, style: text.bodyMedium)
        else
          RegisterGroup(
            children: [
              for (final item in items)
                RegisterRow(
                  icon: kindIcon(item.kind),
                  title: item.title,
                  subtitle: kindLabel(l10n, item.kind),
                  showChevron: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '${l10n.flItemEdit}: ${item.title}',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: busy
                            ? null
                            : () => _edit(context, ref, item),
                      ),
                      IconButton(
                        tooltip: '${l10n.flItemDelete}: ${item.title}',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: busy
                            ? null
                            : () => _delete(context, ref, item),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        if (full)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
            child: Text(l10n.flPortLimit, style: text.bodyMedium),
          ),
        add(
          l10n.flPortAddPhoto,
          Icons.add_a_photo_outlined,
          PortfolioKind.image,
        ),
        add(l10n.flPortAddClip, Icons.movie_outlined, PortfolioKind.videoFile),
        add(
          l10n.flPortAddVideoLink,
          Icons.play_circle_outline_rounded,
          PortfolioKind.videoLink,
        ),
        add(l10n.flPortAddLink, Icons.link_rounded, PortfolioKind.link),
      ],
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    PortfolioKind kind,
  ) async {
    final l10n = AppLocalizations.of(context);
    final draft = await _showSheet(context, kind: kind);
    if (draft == null || !context.mounted) return;
    final actions = ref.read(freelanceActionsProvider.notifier);
    final failure = switch (kind) {
      PortfolioKind.image => await actions.addPhoto(
        title: draft.title,
        description: draft.description,
      ),
      PortfolioKind.videoFile => await actions.addClip(
        title: draft.title,
        description: draft.description,
      ),
      _ => await actions.addLink(
        kind,
        draft.url ?? '',
        title: draft.title,
        description: draft.description,
      ),
    };
    if (failure != null && context.mounted) {
      _toast(context, freelanceFailureText(l10n, failure));
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    FreelancePortfolioItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final draft = await _showSheet(context, existing: item);
    if (draft == null || !context.mounted) return;
    final failure = await ref
        .read(freelanceActionsProvider.notifier)
        .updateItem(
          item.id,
          title: draft.title,
          description: draft.description,
        );
    if (failure != null && context.mounted) {
      _toast(context, freelanceFailureText(l10n, failure));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FreelancePortfolioItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.flItemDeleteTitle),
        content: Text(l10n.flItemDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.flItemDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final failure = await ref
        .read(freelanceActionsProvider.notifier)
        .removeItem(item);
    if (failure != null && context.mounted) {
      _toast(context, freelanceFailureText(l10n, failure));
    }
  }

  Future<_ItemDraft?> _showSheet(
    BuildContext context, {
    PortfolioKind? kind,
    FreelancePortfolioItem? existing,
  }) => showModalBottomSheet<_ItemDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _ItemSheet(kind: kind, existing: existing),
    ),
  );
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({this.kind, this.existing});

  /// The kind being added; null when editing.
  final PortfolioKind? kind;
  final FreelancePortfolioItem? existing;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _desc = TextEditingController(text: widget.existing?.description);
  final _url = TextEditingController();
  String? _titleError;
  String? _descError;
  String? _urlError;

  bool get _hasUrl =>
      widget.kind == PortfolioKind.videoLink ||
      widget.kind == PortfolioKind.link;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final titleOk = FreelanceRules.titleOk(_title.text);
    final descOk = FreelanceRules.descriptionOk(_desc.text);
    final urlOk =
        !_hasUrl ||
        (widget.kind == PortfolioKind.videoLink
            ? FreelanceRules.videoLinkOk(_url.text)
            : FreelanceRules.linkOk(_url.text));
    setState(() {
      _titleError = titleOk ? null : l10n.flErrTitle;
      _descError = descOk ? null : l10n.flErrDescription;
      _urlError = urlOk
          ? null
          : (widget.kind == PortfolioKind.videoLink
                ? l10n.flErrUrlVideo
                : l10n.flErrUrlLink);
    });
    if (!titleOk || !descOk || !urlOk) return;
    final desc = _desc.text.trim();
    Navigator.of(context).pop(
      _ItemDraft(
        _title.text.trim(),
        desc.isEmpty ? null : desc,
        _hasUrl ? _url.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = widget.kind;
    final needsFile =
        kind == PortfolioKind.image || kind == PortfolioKind.videoFile;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              kind == null ? l10n.flItemEdit : kindLabel(l10n, kind),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.flFieldTitle,
            controller: _title,
            errorText: _titleError,
            maxLength: FreelanceRules.titleMax,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.flFieldDescription,
            controller: _desc,
            errorText: _descError,
            maxLines: 3,
            maxLength: FreelanceRules.descriptionMax,
          ),
          if (_hasUrl) ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: l10n.flFieldUrl,
              controller: _url,
              errorText: _urlError,
              hint: kind == PortfolioKind.videoLink
                  ? 'https://youtu.be/…'
                  : 'https://…',
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: widget.existing != null
                ? l10n.save
                : (needsFile ? l10n.flSheetChooseFile : l10n.flSheetAdd),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
