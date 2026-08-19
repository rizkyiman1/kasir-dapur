import 'package:image_picker/image_picker.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';

final class ImagePickerLogoPicker implements LogoPicker {
  ImagePickerLogoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImagePath() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    return file?.path;
  }
}
