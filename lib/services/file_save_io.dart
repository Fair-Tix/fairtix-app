import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<bool> saveBytesImpl({
  required String fileName,
  required String extension,
  required Uint8List bytes,
}) async {
  final downloadName = fileName.endsWith('.$extension')
      ? fileName
      : '$fileName.$extension';
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save report',
    fileName: downloadName,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes,
  );
  if (path == null) return false;

  // Mobile implementations of saveFile already write [bytes]. Desktop
  // only returns a path, so the file still has to be written here.
  if (Platform.isAndroid || Platform.isIOS) return true;
  await File(path).writeAsBytes(bytes);
  return true;
}
