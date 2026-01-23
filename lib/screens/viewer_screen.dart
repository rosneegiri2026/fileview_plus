import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf_render/pdf_render.dart';

class ViewerScreen extends StatefulWidget {
  final File file;
  const ViewerScreen({super.key, required this.file});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  String? textContent;
  bool saving = false;
  bool darkMode = false;

  final PdfViewerController _pdfController = PdfViewerController();
  int currentPage = 1;
  int totalPages = 0;

  String get extension => widget.file.path.split('.').last.toLowerCase();

  @override
  void initState() {
    super.initState();
    loadText();
  }

  Future<void> loadText() async {
    if (extension == 'txt') {
      textContent = await widget.file.readAsString();
    } else if (extension == 'docx') {
      final bytes = await widget.file.readAsBytes();
      textContent = docxToText(bytes);
    }
    setState(() {});
  }

  // ================= SAVE PDF / FILE =================
  Future<void> saveFile() async {
    if (extension != 'pdf') {
      final outputDir =
          Directory('/storage/emulated/0/Download/FileViewPlus');
      if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

      final dest =
          File('${outputDir.path}/${widget.file.path.split('/').last}');
      await widget.file.copy(dest.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${outputDir.path}')),
      );
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save PDF'),
        content:
            const Text('Do you want to save the current page or all pages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'single'),
            child: const Text('Current Page'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('All Pages'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (choice == null || choice == 'cancel') return;

    setState(() => saving = true);
    final outputDir = Directory('/storage/emulated/0/Download/FileViewPlus');
    if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

    try {
      final pdf = await PdfDocument.openFile(widget.file.path);

      int start = 1, end = pdf.pageCount;
      if (choice == 'single') start = end = currentPage;

      for (int i = start; i <= end; i++) {
        final page = await pdf.getPage(i);
        final pageImage = await page.render(
          width: (page.width * 2).toInt(),
          height: (page.height * 2).toInt(),
        );

        final image = await pageImage.createImageDetached();
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final file = File('${outputDir.path}/page_$i.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }

        pageImage.dispose();
        image.dispose();
      }

      await pdf.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${outputDir.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => saving = false);
  }

  // ================= FILE INFO =================
  void showInfo() {
    final stat = widget.file.statSync();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _info('Name', widget.file.path.split('/').last),
            _info('Type', extension.toUpperCase()),
            _info('Size', '${stat.size} bytes'),
            _info('Modified', stat.modified.toString()),
          ],
        ),
      ),
    );
  }

  Widget _info(String t, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
                child:
                    Text(t, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  // ================= VIEWER =================
  Widget viewer() {
    if (extension == 'pdf') {
      Widget pdfViewer = SfPdfViewer.file(
        widget.file,
        controller: _pdfController,
        onDocumentLoaded: (d) {
          setState(() => totalPages = d.document.pages.count);
        },
        onPageChanged: (d) {
          setState(() => currentPage = d.newPageNumber);
        },
      );

      // ========= DARK MODE FOR PDF =========
      if (darkMode) {
        pdfViewer = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            -1,  0,  0, 0, 255,
             0, -1,  0, 0, 255,
             0,  0, -1, 0, 255,
             0,  0,  0, 1,   0,
          ]),
          child: pdfViewer,
        );
      }

      return Stack(
        children: [
          pdfViewer,
          Positioned(
            right: 16,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.black38,
                  child: Text(
                    'Page $currentPage / $totalPages',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ===== TEXT / DOCX FILES =====
    return Container(
      color: darkMode ? Colors.black : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          textContent ?? 'Loading...',
          style: TextStyle(
            fontSize: 16,
            height: 1.7,
            color: darkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: darkMode ? Colors.black : Colors.grey[50],
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFA3C7E4), Color(0xFF99B8EE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                        child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    )),
                    IconButton(
                      icon: Icon(darkMode ? Icons.light_mode : Icons.dark_mode,
                          color: Colors.white),
                      onPressed: () => setState(() => darkMode = !darkMode),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: viewer(),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFA3C7E4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navBarButton(
                  icon: Icons.download,
                  label: 'Save',
                  onTap: saveFile,
                ),
                _navBarButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () => Share.shareXFiles([XFile(widget.file.path)]),
                ),
                _navBarButton(
                  icon: Icons.info_outline,
                  label: 'Info',
                  onTap: showInfo,
                ),
              ],
            ),
          ),
        ),
        if (saving)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navBarButton(
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
