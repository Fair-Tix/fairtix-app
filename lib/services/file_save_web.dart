// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download. [file_picker]'s [saveFile] is not
/// implemented on Flutter web and throws UnimplementedError.
Future<bool> saveBytesImpl({
  required String fileName,
  required String extension,
  required Uint8List bytes,
}) async {
  final mime = extension == 'pdf'
      ? 'application/pdf'
      : 'text/csv;charset=utf-8';
  final downloadName = fileName.endsWith('.$extension')
      ? fileName
      : '$fileName.$extension';
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', downloadName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}
