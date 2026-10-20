import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'csv_export.dart' show saveBytesFile;
import 'report_format.dart';
import 'report_logo.dart';

const _brand = PdfColor.fromInt(0xFF4C1D95);
const _brandSoft = PdfColor.fromInt(0xFFF5F3FF);
const _ink = PdfColor.fromInt(0xFF1F2937);
const _muted = PdfColor.fromInt(0xFF6B7280);

/// Builds a branded PDF with one table from [rows] (first row = header), the
/// same row shape the CSV exports use. Landscape A4 with the FairTix logo,
/// report title, range and generated time in the header, money / count
/// columns right-aligned and formatted, the table header repeated on every
/// page, and a confidentiality + page-number footer. Set [showTotals] to add
/// a totals box under the table (sums of the "(PHP)" and ticket columns).
///
/// Uses the PDF built-in Helvetica font, which has no peso sign, so money
/// columns are labelled "(PHP)" (the report headers already are).
Future<Uint8List> buildReportPdf({
  required String title,
  String? subtitle,
  required List<List<Object?>> rows,
  bool showTotals = false,
}) async {
  final doc = pw.Document(title: title, author: 'FairTix', creator: 'FairTix');
  final header = rows.isEmpty ? const <Object?>[] : rows.first;
  final body = rows.length <= 1 ? const <List<Object?>>[] : rows.sublist(1);
  final generatedLabel = ReportFormat.stamp(DateTime.now());

  pw.MemoryImage? logo;
  try {
    final bytes = await loadReportLogo();
    if (bytes != null) logo = pw.MemoryImage(bytes);
  } catch (e) {
    debugPrint('Report logo could not be added to the PDF: $e');
    logo = null; // A bad logo file must never block an export.
  }

  // Wide reports (12 columns) need a smaller font to fit the page.
  final fontSize = header.length > 9 ? 6.5 : 8.0;

  final alignments = <int, pw.Alignment>{
    for (var i = 0; i < header.length; i++)
      if (ReportFormat.isRightAligned(header[i])) i: pw.Alignment.centerRight,
  };

  final data = [
    for (final row in body)
      [
        for (var i = 0; i < row.length; i++)
          ReportFormat.cell(i < header.length ? header[i] : null, row[i], forPdf: true),
      ],
  ];

  final totals = showTotals && body.isNotEmpty
      ? ReportFormat.totals(rows)
      : const <int, num>{};

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      maxPages: 2000,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.SizedBox(
                  height: 38,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FairTix',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand,
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      ReportFormat.pdfSafe(title),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'GENERATED',
                    style: const pw.TextStyle(fontSize: 6.5, color: _muted),
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    generatedLabel,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 7),
          pw.Container(height: 2, color: _brand),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              ReportFormat.pdfSafe(subtitle),
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Container(height: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'FairTix  |  Confidential - for authorized use only',
                style: const pw.TextStyle(fontSize: 7, color: _muted),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: _muted),
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        if (body.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 24),
            child: pw.Text(
              'No records in this range.',
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: [for (final h in header) ReportFormat.pdfSafe(h?.toString() ?? '')],
            data: data,
            headerStyle: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _brand),
            cellStyle: pw.TextStyle(fontSize: fontSize, color: _ink),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignments: alignments,
            headerAlignments: alignments,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            oddRowDecoration: const pw.BoxDecoration(color: _brandSoft),
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.4),
              bottom: const pw.BorderSide(color: PdfColors.grey500, width: 0.6),
            ),
            defaultColumnWidth: const pw.FlexColumnWidth(),
          ),
        if (body.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          if (totals.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _brandSoft,
                border: pw.Border.all(color: _brand, width: 0.6),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TOTALS',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _brand,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 30,
                    runSpacing: 8,
                    children: [
                      for (final entry in totals.entries)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              header[entry.key]
                                  .toString()
                                  .replaceAll(' (PHP)', '')
                                  .toUpperCase(),
                              style: const pw.TextStyle(fontSize: 6.5, color: _muted),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              '${ReportFormat.isMoney(header[entry.key]) ? 'PHP ' : ''}'
                              '${ReportFormat.formatTotal(header[entry.key], entry.value, forPdf: true)}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Total records: ${body.length}',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Builds the PDF and saves it through the same save dialog as the CSV
/// exports. Returns false if the person canceled.
Future<bool> savePdfReport({
  required String fileName,
  required String title,
  String? subtitle,
  required List<List<Object?>> rows,
  bool showTotals = false,
}) async {
  final bytes = await buildReportPdf(
    title: title,
    subtitle: subtitle,
    rows: rows,
    showTotals: showTotals,
  );
  return saveBytesFile(fileName: fileName, extension: 'pdf', bytes: bytes);
}
