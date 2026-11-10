import 'dart:typed_data';

/// Most photos one professional can keep (also enforced by the database).
const maxPortfolioPhotos = 12;

/// The bucket allows 2 MB; photos are prepared to stay below this.
const maxUploadBytes = 1900 * 1024;

class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.path,
    required this.url,
  });
  final String id;

  /// `<professional id>/<file>` inside the bucket.
  final String path;

  /// Public address of the photo.
  final String url;
}

/// A photo ready to upload: small, JPEG, without location or camera metadata.
class PreparedPhoto {
  const PreparedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });
  final Uint8List bytes;
  final int width;
  final int height;
}

enum PortfolioFailure {
  network,
  notSignedIn,
  forbidden,
  limitReached,

  /// Even after shrinking, the photo is above the upload limit.
  tooLarge,

  /// The file could not be read as a photo.
  notAnImage,
  notConfigured,
  unknown,
}

class PortfolioError implements Exception {
  const PortfolioError(this.failure);
  final PortfolioFailure failure;
  @override
  String toString() => 'PortfolioError($failure)';
}

abstract interface class PortfolioRepository {
  /// Photos of a professional, oldest first. Empty when there is none or the
  /// profile is not visible.
  Future<List<PortfolioItem>> list(String professionalId);

  /// Uploads [photo] to the signed-in professional's portfolio.
  Future<PortfolioItem> add(PreparedPhoto photo);

  Future<void> remove(PortfolioItem item);
}

class NotConfiguredPortfolioRepository implements PortfolioRepository {
  const NotConfiguredPortfolioRepository();
  @override
  Future<List<PortfolioItem>> list(String professionalId) async => const [];
  @override
  Future<PortfolioItem> add(PreparedPhoto photo) async =>
      throw const PortfolioError(PortfolioFailure.notConfigured);
  @override
  Future<void> remove(PortfolioItem item) async =>
      throw const PortfolioError(PortfolioFailure.notConfigured);
}

/// Picks one photo from the device. Null when the person cancels.
abstract interface class PhotoPicker {
  Future<Uint8List?> pick();
}
