import 'package:file_picker/file_picker.dart';

class FileService {
  static Future<PlatformFile?> pickFile({required bool allowMultiple}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );
    return result?.files.first;
  }
}
