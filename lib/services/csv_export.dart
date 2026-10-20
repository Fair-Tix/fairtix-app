import 'dart:convert';
import 'dart:typed_data';

import 'file_save_stub.dart'
    if (dart.library.html) 'file_save_web.dart'
    if (dart.library.io) 'file_save_io.dart';
import 'report_format.dart';

/// Saves [bytes] as a file named [fileName] (with the given [extension], no
/// dot, e.g. 'csv' or 'pdf') on every platform the app runs on:
///  - Web: triggers a browser download (file_picker.saveFile is not
///    implemented on Flutter web).
///  - Android / iOS: opens the system "save to" sheet.
///  - Windows / macOS / Linux: opens a save dialog, then writes the file.
///
/// Returns true if the file was saved (or, on web, the download was
/// started), false if the person canceled the save dialog.
Future<bool> saveBytesFile({
  required String fileName,
  required String extension,
  required Uint8List bytes,
}) {
  return saveBytesImpl(
    fileName: fileName,
    extension: extension,
    bytes: bytes,
  );
}

/// Saves [csv] as a UTF-8 file named [fileName]. See [saveBytesFile].
Future<bool> saveCsvFile({
  required String fileName,
  required String csv,
}) {
  // A BOM makes Excel open the file as UTF-8, so names and the peso sign
  // aren't garbled.
  final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
  return saveBytesFile(fileName: fileName, extension: 'csv', bytes: bytes);
}

/// Guards a text cell against spreadsheet formula injection: text that
/// starts with = + - @ gets a leading apostrophe, so Excel or Sheets can't
/// run a user-supplied name or event title as a formula. Non-text values
/// (numbers, null) pass through unchanged.
Object? csvSafe(Object? value) {
  if (value is String && value.isNotEmpty && '=+-@'.contains(value[0])) {
    return "'$value";
  }
  return value;
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

/// Like [toCsv], but runs every cell through [csvSafe] first. Use this for
/// report rows that hold raw (unescaped) values, so the same rows can also
/// be printed to a PDF without a stray apostrophe.
String toSafeCsv(List<List<Object?>> rows) {
  return toCsv([
    for (final row in rows) [for (final value in row) csvSafe(value)],
  ]);
}

/// Builds a presentable report CSV from [rows] (first row = header):
/// a FairTix / report title / range / generated-at block, a blank line, the
/// table with money to 2 decimals and dates made readable, then an optional
/// TOTAL row and a record count. Text cells are formula-injection safe.
String buildReportCsv({
  required String title,
  String? subtitle,
  required List<List<Object?>> rows,
  bool showTotals = false,
}) {
  final header = rows.isEmpty ? const <Object?>[] : rows.first;
  final body = rows.length <= 1 ? const <List<Object?>>[] : rows.sublist(1);

  Object? headerAt(int i) => i < header.length ? header[i] : null;

  // Numbers are written as plain text so csvSafe can't prefix a negative
  // amount with an apostrophe; everything else goes through csvSafe.
  Object? cellOf(int i, Object? value) {
    final text = ReportFormat.cell(headerAt(i), value, forPdf: false);
    return ReportFormat.isNumeric(headerAt(i)) ? text : csvSafe(text);
  }

  final out = <List<Object?>>[
    const ['FairTix'],
    [csvSafe(title)],
    if (subtitle != null && subtitle.isNotEmpty) [csvSafe(subtitle)],
    ['Generated: ${ReportFormat.stamp(DateTime.now())}'],
    const [],
    [for (final h in header) csvSafe(h?.toString())],
  ];

  if (body.isEmpty) {
    out.add(const ['No records in this range.']);
  } else {
    for (final row in body) {
      out.add([for (var i = 0; i < row.length; i++) cellOf(i, row[i])]);
    }
    if (showTotals) {
      final totals = ReportFormat.totals(rows);
      if (totals.isNotEmpty) {
        out.add([
          for (var i = 0; i < header.length; i++)
            i == 0
                ? 'TOTAL'
                : totals.containsKey(i)
                ? ReportFormat.formatTotal(header[i], totals[i]!, forPdf: false)
                : '',
        ]);
      }
    }
    out.add(const []);
    out.add(['Total records: ${body.length}']);
  }

  return toCsv(out);
}

/// Saves a presentable report CSV. See [buildReportCsv] and [saveBytesFile].
Future<bool> saveCsvReport({
  required String fileName,
  required String title,
  String? subtitle,
  required List<List<Object?>> rows,
  bool showTotals = false,
}) {
  final csv = buildReportCsv(
    title: title,
    subtitle: subtitle,
    rows: rows,
    showTotals: showTotals,
  );
  return saveCsvFile(fileName: fileName, csv: csv);
}
