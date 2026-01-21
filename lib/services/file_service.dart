import 'package:file_picker/file_picker.dart';

class FileService {
  static Future<PlatformFile?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );

    if (result != null) {
      return result.files.first;
    }
    return null;
  }
}
