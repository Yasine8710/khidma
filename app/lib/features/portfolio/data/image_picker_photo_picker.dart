import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../domain/portfolio_domain.dart';

/// Picks from the photo library with the system picker (no permission needed
/// on current iOS and Android versions). The camera is not used.
class ImagePickerPhotoPicker implements PhotoPicker {
  const ImagePickerPhotoPicker();

  @override
  Future<Uint8List?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Large originals are shrunk by the picker already; the app prepares the
      // final upload either way.
      maxWidth: 2400,
      maxHeight: 2400,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }
}
