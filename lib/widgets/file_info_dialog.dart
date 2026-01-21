import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FileInfoDialog extends StatelessWidget {
  final PlatformFile file;
  const FileInfoDialog({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("File Information"),
      content: Text(
        "Name: ${file.name}\n"
        "Size: ${file.size} bytes\n"
        "Type: ${file.extension}\n"
        "Path: ${file.path}",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
