import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

Future<String?> pickCsvFileForImport() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );
  return file?.path;
}

Future<bool> saveCsvExportFile(String filePath) async {
  final bytes = await File(filePath).readAsBytes();
  final savedPath = await FilePicker.saveFile(
    dialogTitle: 'Save CSV export',
    fileName: p.basename(filePath),
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );
  return savedPath != null;
}
