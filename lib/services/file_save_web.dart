import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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

  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = downloadName;
  anchor.click();

  web.URL.revokeObjectURL(url);
  return true;
}
