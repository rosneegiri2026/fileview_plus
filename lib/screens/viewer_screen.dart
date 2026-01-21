import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ViewerScreen extends StatefulWidget {
  final File file;
  const ViewerScreen({super.key, required this.file});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  String? textContent;

  String get extension => widget.file.path.split('.').last.toLowerCase();

  @override
  void initState() {
    super.initState();
    loadText();
  }

  // Load TXT or DOCX content
  Future<void> loadText() async {
    if (extension == 'txt') {
      textContent = await widget.file.readAsString();
    } else if (extension == 'docx') {
      final bytes = await widget.file.readAsBytes();
      textContent = docxToText(bytes);
    }
    setState(() {});
  }

  // Request storage permission
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  //SAVE FULL PDF AS IMAGES 
  Future<void> saveWholePdfAsImages() async {
  try {
    final granted = await requestStoragePermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required')),
      );
      return;
    }

    final pdfBytes = await widget.file.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }


    document.dispose();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All PDF pages saved as images')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}


  // File info dialog
  void showInfo() {
    final stat = widget.file.statSync();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('File Info'),
        content: Text(
          'Name: ${widget.file.path.split('/').last}\n'
          'Type: $extension\n'
          'Size: ${stat.size} bytes\n'
          'Last Modified: ${stat.modified}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Viewer widget
  Widget viewer() {
    if (extension == 'pdf') {
      return SfPdfViewer.file(widget.file);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        textContent ?? 'Loading...',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.file.path.split('/').last,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(child: viewer()),

          // Bottom actions
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed:
                      extension == 'pdf' ? saveWholePdfAsImages : null,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () =>
                      Share.shareXFiles([XFile(widget.file.path)]),
                ),
                IconButton(
                  icon: const Icon(Icons.info),
                  onPressed: showInfo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
