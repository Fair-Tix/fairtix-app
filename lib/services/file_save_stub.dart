import 'dart:typed_data';

Future<bool> saveBytesImpl({
  required String fileName,
  required String extension,
  required Uint8List bytes,
}) async {
  throw UnsupportedError(
    'Saving files is not supported on this platform.',
  );
}
