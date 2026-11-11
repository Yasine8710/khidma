import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../application/profile_providers.dart';

/// The signed-in person's picture with a camera badge. Tapping it opens a
/// small sheet to choose a photo or remove the current one. Without a picture
/// it shows initials, like everywhere else.
class AvatarEditor extends ConsumerWidget {
  const AvatarEditor({super.key, this.size = 96, this.onPhoto = false});

  final double size;

  /// Draws a white ring so the picture stands out on a blue or photo
  /// background (headers).
  final bool onPhoto;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final has = ref.read(visibleProfileProvider)?.avatarUrl != null;
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.avatarChoose),
              onTap: () => Navigator.of(context).pop(_Choice.pick),
            ),
            if (has)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(l10n.avatarRemove),
                onTap: () => Navigator.of(context).pop(_Choice.remove),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final actions = ref.read(profileActionsProvider.notifier);
    final result = choice == _Choice.pick
        ? await actions.pickAvatar()
        : await actions.removeAvatar();
    if (result != null && !result.isOk) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.avatarFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(visibleProfileProvider);
    final busy = ref.watch(profileActionsProvider);
    final badge = (size * 0.34).clamp(28.0, 40.0);
    return Semantics(
      button: true,
      label: l10n.avatarChange,
      excludeSemantics: true,
      onTap: busy ? null : () => _open(context, ref),
      child: GestureDetector(
        onTap: busy ? null : () => _open(context, ref),
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: onPhoto
                      ? Border.all(color: Colors.white, width: 4)
                      : null,
                  boxShadow: AppColors.softShadow,
                ),
                child: AppAvatar(
                  name: profile?.fullName ?? '',
                  imageUrl: profile?.avatarUrl,
                  size: size,
                  decorative: true,
                ),
              ),
              if (busy)
                SizedBox(
                  width: size,
                  height: size,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: badge * 0.5,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Choice { pick, remove }
