import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Saves [csv] as a UTF-8 file named [fileName] on every platform the app
/// runs on, using the file_picker package the app already depends on:
///  - Web: triggers a browser download.
///  - Android / iOS: opens the system "save to" sheet; file_picker writes
///    the bytes.
///  - Windows / macOS / Linux: opens a save dialog, then the file is
///    written here (file_picker only returns the chosen path on desktop).
///
/// Returns true if the file was saved (or, on web, the download was
/// started), false if the person canceled the save dialog.
Future<bool> saveCsvFile({
  required String fileName,
  required String csv,
}) async {
  // A BOM makes Excel open the file as UTF-8, so names and the peso sign
  // aren't garbled.
  final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save report',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: bytes,
  );

  if (kIsWeb) return true;

  final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (isDesktop) {
    if (path == null) return false;
    await File(path).writeAsBytes(bytes);
    return true;
  }

  // Mobile: a null result means the sheet was dismissed.
  return path != null;
}

/// Turns [rows] (first row = header) into CSV text, quoting any cell that
/// contains a comma, quote, or line break.
String toCsv(List<List<Object?>> rows) {
  String cell(Object? value) {
    final text = value == null ? '' : value.toString();
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  return rows.map((row) => row.map(cell).join(',')).join('\r\n');
}
