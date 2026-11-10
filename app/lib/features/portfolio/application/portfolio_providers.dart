import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_picker_photo_picker.dart';
import '../data/image_prep.dart';
import '../domain/portfolio_domain.dart';

/// Overridden in `main()` with the Supabase repository when configured.
final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => const NotConfiguredPortfolioRepository(),
);

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => const ImagePickerPhotoPicker(),
);

/// Prepares a picked photo for upload. Replaced in tests (the real one decodes
/// and re-encodes the image in a background isolate).
final photoPreparerProvider =
    Provider<Future<PreparedPhoto> Function(Uint8List)>(
      (ref) => preparePhotoInBackground,
    );

final portfolioProvider = FutureProvider.autoDispose
    .family<List<PortfolioItem>, String>(
      retry: (n, e) => null,
      (ref, professionalId) =>
          ref.watch(portfolioRepositoryProvider).list(professionalId),
    );

/// Adds and removes photos. [busy] is true while one runs.
final portfolioActionsProvider = NotifierProvider<PortfolioActions, bool>(
  PortfolioActions.new,
);

class PortfolioActions extends Notifier<bool> {
  @override
  bool build() => false;

  /// Picks, prepares and uploads one photo. Returns null on success or when
  /// the person cancels; otherwise the failure.
  Future<PortfolioFailure?> addFromLibrary(String professionalId) async {
    if (state) return null;
    state = true;
    try {
      final picked = await ref.read(photoPickerProvider).pick();
      if (picked == null) return null;
      final prepared = await ref.read(photoPreparerProvider)(picked);
      await ref.read(portfolioRepositoryProvider).add(prepared);
      if (ref.mounted) ref.invalidate(portfolioProvider(professionalId));
      return null;
    } on PortfolioError catch (e) {
      return e.failure;
    } catch (_) {
      return PortfolioFailure.unknown;
    } finally {
      if (ref.mounted) state = false;
    }
  }

  Future<PortfolioFailure?> remove(
    String professionalId,
    PortfolioItem item,
  ) async {
    if (state) return null;
    state = true;
    try {
      await ref.read(portfolioRepositoryProvider).remove(item);
      if (ref.mounted) ref.invalidate(portfolioProvider(professionalId));
      return null;
    } on PortfolioError catch (e) {
      return e.failure;
    } catch (_) {
      return PortfolioFailure.unknown;
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
