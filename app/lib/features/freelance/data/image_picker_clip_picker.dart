import 'package:image_picker/image_picker.dart';

import '../domain/freelance_domain.dart';

/// Picks a short clip from the library with the system picker (no permission
/// needed). The picker limits the length to [FreelanceRules.maxClipSeconds];
/// the size and the format (mp4 or webm, what the bucket accepts) are checked
/// here before anything is read into memory.
class ImagePickerClipPicker implements ClipPicker {
  const ImagePickerClipPicker();

  @override
  Future<PickedClip?> pick() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: FreelanceRules.maxClipSeconds),
    );
    if (file == null) return null;
    final ext = clipExtension(file.name.isNotEmpty ? file.name : file.path);
    if (ext == null) {
      throw const FreelanceError(FreelanceFailure.unsupportedFormat);
    }
    if (await file.length() > FreelanceRules.maxFileBytes) {
      throw const FreelanceError(FreelanceFailure.tooLarge);
    }
    return PickedClip(bytes: await file.readAsBytes(), extension: ext);
  }
}

/// `mp4` or `webm` for a file name, null for anything else (e.g. `.mov`).
String? clipExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  return ext == 'mp4' || ext == 'webm' ? ext : null;
}
