import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/portfolio_domain.dart';

/// Longest side after preparing: plenty for a phone screen, small to upload.
const maxPhotoSide = 1600;

/// The largest original accepted (a bigger file is refused before decoding).
const maxOriginalBytes = 25 * 1024 * 1024;

/// Reads [input] as an image, turns it upright, shrinks it to [maxPhotoSide]
/// and re-encodes it as JPEG below [maxUploadBytes]. Re-encoding drops all
/// metadata (GPS position, camera model, ...). Throws [PortfolioError].
PreparedPhoto preparePhoto(Uint8List input) {
  if (input.isEmpty || input.length > maxOriginalBytes) {
    throw const PortfolioError(PortfolioFailure.tooLarge);
  }
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null || decoded.width < 1 || decoded.height < 1) {
    throw const PortfolioError(PortfolioFailure.notAnImage);
  }
  var image = img.bakeOrientation(decoded);
  // Nothing from the original's metadata is carried over (GPS, camera, ...).
  image.exif = img.ExifData();
  image.iccProfile = null;

  // Quality first, then size, until it fits.
  for (final (side, quality) in const [
    (maxPhotoSide, 82),
    (maxPhotoSide, 70),
    (1280, 70),
    (1024, 65),
    (800, 60),
  ]) {
    final longest = image.width > image.height ? image.width : image.height;
    final scaled = longest > side
        ? img.copyResize(
            image,
            width: image.width >= image.height ? side : null,
            height: image.height > image.width ? side : null,
            interpolation: img.Interpolation.average,
          )
        : image;
    final bytes = Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
    if (bytes.length <= maxUploadBytes) {
      return PreparedPhoto(
        bytes: bytes,
        width: scaled.width,
        height: scaled.height,
      );
    }
    image = scaled;
  }
  throw const PortfolioError(PortfolioFailure.tooLarge);
}

/// [preparePhoto] off the UI thread (decoding a 12 MP photo takes a moment).
Future<PreparedPhoto> preparePhotoInBackground(Uint8List input) =>
    compute(preparePhoto, input);
