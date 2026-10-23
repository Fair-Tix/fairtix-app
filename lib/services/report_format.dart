/// Shared cell formatting and totals for the CSV and PDF report exports, so
/// both formats show the same clean values.
class ReportFormat {
  ReportFormat._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}.*)?$');

  /// Money columns are labelled "(PHP)" in the report headers.
  static bool isMoney(Object? header) => '$header'.contains('(PHP)');

  static bool isCount(Object? header) {
    final h = '$header'.trim().toLowerCase();
    return h == 'tickets sold' || h == 'tickets';
  }

  static bool isNumeric(Object? header) => isMoney(header) || isCount(header);

  static bool isRightAligned(Object? header) =>
      isNumeric(header) || '$header'.trim().toLowerCase() == 'fee rate';

  static num? toNum(Object? value) {
    if (value is num) return value;
    if (value == null) return null;
    return num.tryParse(value.toString().trim());
  }

  static String _group(String digits) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  /// 2 decimals; thousands separators for the PDF, none for the CSV so
  /// Excel still reads the cell as a number.
  static String money(Object? value, {required bool grouped}) {
    final n = toNum(value);
    if (n == null) return value == null ? '' : value.toString();
    final parts = n.abs().toStringAsFixed(2).split('.');
    final whole = grouped ? _group(parts[0]) : parts[0];
    return '${n < 0 ? '-' : ''}$whole.${parts[1]}';
  }

  static String count(Object? value, {required bool grouped}) {
    final n = toNum(value);
    if (n == null) return value == null ? '' : value.toString();
    final text = n.abs().round().toString();
    return '${n < 0 ? '-' : ''}${grouped ? _group(text) : text}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 'yyyy-MM-dd HH:mm'
  static String stamp(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  /// "Oct 20, 2026" / "Oct 20, 2026 3:45 PM" for the PDF; sortable
  /// "2026-10-20" / "2026-10-20 15:45" for the CSV. Returns null if [text]
  /// isn't a date.
  static String? _date(String text, {required bool forPdf}) {
    if (!_isoDate.hasMatch(text)) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    final hasTime = text.length > 10;
    if (!hasTime) {
      return forPdf
          ? '${_months[parsed.month - 1]} ${parsed.day}, ${parsed.year}'
          : text;
    }
    final local = parsed.toLocal();
    if (!forPdf) return stamp(local);
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${_months[local.month - 1]} ${local.day}, ${local.year} '
        '$hour12:${_two(local.minute)} $suffix';
  }

  /// Formats one table cell according to its column [header].
  static String cell(Object? header, Object? value, {required bool forPdf}) {
    if (value == null) return '';
    final String text;
    if (isMoney(header)) {
      text = money(value, grouped: forPdf);
    } else if (isCount(header)) {
      text = count(value, grouped: forPdf);
    } else {
      final raw = value.toString();
      text = _date(raw, forPdf: forPdf) ?? raw;
    }
    return forPdf ? pdfSafe(text) : text;
  }

  /// The PDF's built-in Helvetica font only covers basic Latin, so common
  /// typographic characters are swapped for plain equivalents instead of
  /// printing as blanks.
  static String pdfSafe(String text) => text
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"')
      .replaceAll('\u2022', '|')
      .replaceAll('\u20B1', 'PHP ')
      .replaceAll('\u2026', '...');

  /// Column index -> sum, for every money / count column that has numbers.
  /// [rows] has the header as its first row.
  static Map<int, num> totals(List<List<Object?>> rows) {
    if (rows.length <= 1) return const {};
    final header = rows.first;
    final sums = <int, num>{};
    for (var i = 0; i < header.length; i++) {
      if (!isNumeric(header[i])) continue;
      var found = false;
      num sum = 0;
      for (final row in rows.skip(1)) {
        if (i >= row.length) continue;
        final n = toNum(row[i]);
        if (n == null) continue;
        found = true;
        sum += n;
      }
      if (found) sums[i] = sum;
    }
    return sums;
  }

  static String formatTotal(Object? header, num value, {required bool forPdf}) =>
      isMoney(header)
          ? money(value, grouped: forPdf)
          : count(value, grouped: forPdf);
}
