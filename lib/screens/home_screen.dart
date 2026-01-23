import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../services/file_service.dart';
import 'viewer_screen.dart';

enum SortType { dateDesc, dateAsc, nameAsc, nameDesc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<File> recentFiles = [];
  final Set<File> selectedFiles = {};
  final Map<String, Uint8List?> pdfThumbnails = {};

  bool isGrid = true;
  SortType sortType = SortType.dateDesc;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  // ================= LOAD & SAVE =================
  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('recentFiles') ?? [];
    recentFiles.addAll(paths.map((e) => File(e)));
    _sortFiles();
    _generatePreviews();
    setState(() {});
  }

  Future<void> _saveRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
      'recentFiles',
      recentFiles.map((f) => f.path).toList(),
    );
  }

  // ================= OPEN FILE =================
  Future<void> openFile() async {
    final result = await FileService.pickFile(allowMultiple: true);
    if (result == null || result.path == null) return;
    final file = File(result.path!);

    setState(() {
      recentFiles.removeWhere((f) => f.path == file.path);
      recentFiles.insert(0, file);
      _sortFiles();
    });

    _saveRecentFiles();
    _generatePreviews();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ViewerScreen(file: file)),
    );
  }

  // ================= SORT =================
  void _sortFiles() {
    recentFiles.sort((a, b) {
      switch (sortType) {
        case SortType.dateAsc:
          return a.lastModifiedSync().compareTo(b.lastModifiedSync());
        case SortType.dateDesc:
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        case SortType.nameAsc:
          return a.path.split('/').last.toLowerCase()
              .compareTo(b.path.split('/').last.toLowerCase());
        case SortType.nameDesc:
          return b.path.split('/').last.toLowerCase()
              .compareTo(a.path.split('/').last.toLowerCase());
      }
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sortTile('Newest first', SortType.dateDesc),
          _sortTile('Oldest first', SortType.dateAsc),
          _sortTile('Name A–Z', SortType.nameAsc),
          _sortTile('Name Z–A', SortType.nameDesc),
        ],
      ),
    );
  }

  Widget _sortTile(String title, SortType type) {
    return ListTile(
      title: Text(title),
      trailing: sortType == type ? const Icon(Icons.check) : null,
      onTap: () {
        setState(() {
          sortType = type;
          _sortFiles();
        });
        Navigator.pop(context);
      },
    );
  }

  // ================= PREVIEWS =================
  Future<void> _generatePreviews() async {
    for (var file in recentFiles) {
      final ext = file.path.split('.').last.toLowerCase();
      if (ext == 'pdf' && pdfThumbnails[file.path] == null) {
        try {
          final doc = await PdfDocument.openFile(file.path);
          final page = await doc.getPage(1);
          final pageImage = await page.render(
            width: (page.width * 0.4).toInt(),
            height: (page.height * 0.4).toInt(),
          );

          final img = await pageImage.createImageDetached();
          final byteData =
              await img.toByteData(format: ui.ImageByteFormat.png);

          if (byteData != null) {
            pdfThumbnails[file.path] = byteData.buffer.asUint8List();
          }

          img.dispose();
          pageImage.dispose();
          doc.dispose();
          if (mounted) setState(() {});
        } catch (_) {}
      }
    }
  }

  // ================= SEARCH + FILTER =================
  List<File> get filteredFiles {
    return recentFiles.where((file) {
      final name = file.path.split('/').last.toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();
  }

  // ================= FILE PREVIEW =================
  Widget _filePreview(File file) {
    final ext = file.path.split('.').last.toLowerCase();

    if (ext == 'pdf' && pdfThumbnails[file.path] != null) {
      return Image.memory(pdfThumbnails[file.path]!, fit: BoxFit.cover);
    }

    IconData icon;
    Color color;

    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'txt':
        icon = Icons.text_snippet;
        color = Colors.grey;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey.shade700;
    }

    return Center(child: Icon(icon, size: 36, color: color));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final files = filteredFiles;
    final isSelectionMode = selectedFiles.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode
            ? '${selectedFiles.length} selected'
            : 'FileView+'),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareSelected,
            ),
          ] else ...[
            IconButton(
              icon: Icon(isGrid ? Icons.view_list : Icons.grid_view),
              onPressed: () => setState(() => isGrid = !isGrid),
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _showSortSheet,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
        ),
      ),
      body: files.isEmpty
          ? const Center(child: Text('No files'))
          : isGrid
              ? _buildGrid(files)
              : _buildList(files),
      floatingActionButton: FloatingActionButton(
        onPressed: openFile,
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  // ================= GRID =================
  Widget _buildGrid(List<File> files) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,          // 3 columns for smaller cards
        childAspectRatio: 0.55,     // compact cards
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) => _fileCard(files[i]),
    );
  }

  // ================= LIST =================
  Widget _buildList(List<File> files) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (_, i) {
        final file = files[i];
        return _listTile(file);
      },
    );
  }

  Widget _listTile(File file) {
    final isSelected = selectedFiles.contains(file);
    return ListTile(
      leading: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : _fileTypeIcon(file),
      title: Text(file.path.split('/').last),
      subtitle: Text(_fileMeta(file)),
      onTap: () {
        if (selectedFiles.isNotEmpty) {
          _toggleSelection(file);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ViewerScreen(file: file)),
          );
        }
      },
      onLongPress: () => _toggleSelection(file),
    );
  }

  // ================= CARD =================
  Widget _fileCard(File file) {
    final preview = _filePreview(file);
    final isSelected = selectedFiles.contains(file);

    return GestureDetector(
      onTap: () {
        if (selectedFiles.isNotEmpty) {
          _toggleSelection(file);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ViewerScreen(file: file)),
          );
        }
      },
      onLongPress: () => _toggleSelection(file),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ===== FILE TYPE ICON ON TOP =====
                Container(
                  height: 24, // smaller icon section
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(child: _fileTypeIcon(file)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: preview,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned.fill(
              child: Container(
                color: Colors.black38,
                child: const Icon(Icons.check_circle,
                    size: 28, color: Colors.white),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Text(
                _fileMeta(file),
                style: const TextStyle(color: Colors.white, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileTypeIcon(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    IconData icon;
    Color color;

    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'txt':
        icon = Icons.text_snippet;
        color = Colors.grey;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey.shade700;
    }

    return Icon(icon, color: color, size: 20);
  }

  void _toggleSelection(File file) {
    setState(() {
      if (selectedFiles.contains(file)) {
        selectedFiles.remove(file);
      } else {
        selectedFiles.add(file);
      }
    });
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Files'),
        content: const Text('Are you sure you want to delete selected files?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                setState(() {
                  for (var file in selectedFiles) {
                    if (file.existsSync()) file.deleteSync();
                    recentFiles.remove(file);
                  }
                  selectedFiles.clear();
                });
                _saveRecentFiles();
                Navigator.pop(context);
              },
              child: const Text('Delete')),
        ],
      ),
    );
  }

  void _shareSelected() {
    if (selectedFiles.isEmpty) return;
    final xfiles = selectedFiles.map((f) => XFile(f.path)).toList();
    Share.shareXFiles(xfiles);
  }

  // ================= FILE META =================
  String _fileMeta(File file) {
    final sizeKB = (file.lengthSync() / 1024).toStringAsFixed(1);
    final date = DateFormat('dd MMM yyyy').format(file.lastModifiedSync());
    return '$sizeKB KB • $date';
  }
}
