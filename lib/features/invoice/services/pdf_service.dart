import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/datasources/storage_service.dart';
import '../../../data/models/invoice.dart';

class PdfService {
  PdfService._();

  // ── Colours ───────────────────────────────────────────────────────────────

  /// Exact gold-yellow from the Timo's Engineering design (#FFCC00)
  static const _yellow = PdfColor.fromInt(0xFFFFCC00);
  static const _black = PdfColors.black;
  static const _white = PdfColors.white;

  /// Borders for totals boxes and inner lines
  static const _borderGrey = PdfColor.fromInt(0xFFCCCCCC);

  /// Faint notebook lines inside the Remarks box
  static const _lineGrey = PdfColor.fromInt(0xFFE2E2E2);

  // ── Text Styles ───────────────────────────────────────────────────────────

  static final _tableHeaderStyle = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );

  static const _tableCellStyle = pw.TextStyle(
    fontSize: 8.5,
    color: _black,
  );

  static final _totalLabelStyle = pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );

  static final _grandTotalValueStyle = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );

  static final _fieldLabelStyle = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );

  static final _sectionTitleStyle = pw.TextStyle(
    fontSize: 9.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );

  // ── Image Cache ───────────────────────────────────────────────────────────

  static pw.MemoryImage? _headerCache;
  static pw.MemoryImage? _invoiceCache;
  static pw.MemoryImage? _customerCache;
  static pw.MemoryImage? _generatorCache;
  static pw.MemoryImage? _footerCache;

  static Future<pw.MemoryImage> _loadHeader() async {
    _headerCache ??= pw.MemoryImage(
      (await rootBundle.load('assets/full_header.png')).buffer.asUint8List(),
    );
    return _headerCache!;
  }

  static Future<pw.MemoryImage> _loadInvoice() async {
    _invoiceCache ??= pw.MemoryImage(
      (await rootBundle.load('assets/invoice.png')).buffer.asUint8List(),
    );
    return _invoiceCache!;
  }

  static Future<pw.MemoryImage> _loadCustomer() async {
    _customerCache ??= pw.MemoryImage(
      (await rootBundle.load('assets/customer_details.png'))
          .buffer
          .asUint8List(),
    );
    return _customerCache!;
  }

  static Future<pw.MemoryImage> _loadGenerator() async {
    _generatorCache ??= pw.MemoryImage(
      (await rootBundle.load('assets/generator_details.png'))
          .buffer
          .asUint8List(),
    );
    return _generatorCache!;
  }

  static Future<pw.MemoryImage> _loadFooter() async {
    _footerCache ??= pw.MemoryImage(
      (await rootBundle.load('assets/full_footer.png')).buffer.asUint8List(),
    );
    return _footerCache!;
  }

  // ── Formatting Helpers ────────────────────────────────────────────────────

  static String _formatMoney(double value) =>
      CurrencyFormatter.formatRaw(value);

  static String _formatMoneyOrBlank(double value) =>
      value > 0 ? CurrencyFormatter.formatRaw(value) : '';

  static String _safe(String? value, [String fallback = '']) =>
      (value == null || value.trim().isEmpty) ? fallback : value.trim();

  static String _sanitizeFilename(String raw) =>
      raw.trim().replaceAll(RegExp(r'[<>:"/\\|?*\s]+'), '_');

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<pw.Document> buildPdf(Invoice invoice) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');

    // Preload all 5 high-resolution graphic assets
    final headerImg = await _loadHeader();
    final invoiceImg = await _loadInvoice();
    final customerImg = await _loadCustomer();
    final generatorImg = await _loadGenerator();
    final footerImg = await _loadFooter();

    const pageWidth = 595.28; // Standard A4 width in pt
    const contentWidth =
        574.0; // Content width with 10.64pt margins on each side
    const hMargin = (pageWidth - contentWidth) / 2;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. Full-bleed Company Header ───────────────────────────────
            pw.Image(
              headerImg,
              width: pageWidth,
              height: pageWidth /
                  3.9174, // Aspect ratio of updated full_header.png (2609x666)
              fit: pw.BoxFit.fill,
            ),

            // ── Body Elements with Horizontal Margins ──────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: hMargin),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.SizedBox(height: 5),

                  // ── 2. INVOICE Banner ────────────────────────────────────
                  _buildInvoiceBanner(
                    invoiceImg,
                    invoice,
                    dateFmt.format(invoice.date),
                    contentWidth,
                  ),
                  pw.SizedBox(height: 5),

                  // ── 3. Customer Details ──────────────────────────────────
                  _buildCustomerSection(customerImg, invoice, contentWidth),
                  pw.SizedBox(height: 5),

                  // ── 4. Generator Details ─────────────────────────────────
                  _buildGeneratorDetails(generatorImg, invoice, contentWidth),
                  pw.SizedBox(height: 5),

                  // ── 5. Items Table ───────────────────────────────────────
                  _buildItemsTable(invoice, contentWidth),
                  pw.SizedBox(height: 5),

                  // ── 6. Report/Remarks + Totals ───────────────────────────
                  _buildRemarksAndTotals(invoice, contentWidth),
                  pw.SizedBox(height: 6),

                  // ── 7. Signature Section ─────────────────────────────────
                  _buildSignatureSection(invoice, contentWidth),
                ],
              ),
            ),

            pw.Spacer(),

            // ── 8. Full-bleed Footer ───────────────────────────────────────
            _buildFooter(footerImg, pageWidth),
          ],
        ),
      ),
    );

    return pdf;
  }

  // ── 2. INVOICE Banner ─────────────────────────────────────────────────────

  static pw.Widget _buildInvoiceBanner(
    pw.MemoryImage bannerImg,
    Invoice invoice,
    String dateStr,
    double width,
  ) {
    // invoice.png aspect ratio: 2581 / 245 = 10.5347
    final height = width / 10.5347;

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          pw.Image(
            bannerImg,
            width: width,
            height: height,
            fit: pw.BoxFit.fill,
          ),
          // Invoice No overlay (line y: 87/245 = 0.355 in invoice.png)
          pw.Positioned(
            left: width * 0.740,
            top: height * 0.15,
            child: pw.SizedBox(
              width: width * 0.235,
              child: pw.Text(
                _safe(invoice.invoiceNumber),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
          // Date overlay (line y: 196/245 = 0.800 in invoice.png)
          pw.Positioned(
            left: width * 0.665,
            top: height * 0.59,
            child: pw.SizedBox(
              width: width * 0.310,
              child: pw.Text(
                dateStr,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Customer Details ───────────────────────────────────────────────────

  static pw.Widget _buildCustomerSection(
    pw.MemoryImage customerImg,
    Invoice invoice,
    double width,
  ) {
    // customer_details.png aspect ratio: 2590 / 331 = 7.8248
    final height = width / 7.8248;

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          pw.Image(
            customerImg,
            width: width,
            height: height,
            fit: pw.BoxFit.fill,
          ),
          // Customer Name (line 1 left, y: 97/331 = 0.293)
          pw.Positioned(
            left: width * 0.205,
            top: height * 0.13,
            child: pw.SizedBox(
              width: width * 0.395,
              child: pw.Text(
                _safe(invoice.clientName),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
          // Bill To (line 1 right, y: 97/331 = 0.293)
          pw.Positioned(
            left: width * 0.715,
            top: height * 0.13,
            child: pw.SizedBox(
              width: width * 0.260,
              child: pw.Text(
                _safe(invoice.billTo),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
          // Customer Address (line 2, y: 190/331 = 0.574)
          pw.Positioned(
            left: width * 0.205,
            top: height * 0.41,
            child: pw.SizedBox(
              width: width * 0.770,
              child: pw.Text(
                _safe(invoice.address),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
          // Customer Phone (line 3, y: 282/331 = 0.852)
          pw.Positioned(
            left: width * 0.205,
            top: height * 0.69,
            child: pw.SizedBox(
              width: width * 0.770,
              child: pw.Text(
                _safe(invoice.phone),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Generator Details ──────────────────────────────────────────────────

  static pw.Widget _buildGeneratorDetails(
    pw.MemoryImage generatorImg,
    Invoice invoice,
    double width,
  ) {
    // generator_details.png aspect ratio: 2590 / 388 = 6.6753
    final height = width / 6.6753;

    String dd = '';
    String mm = '';
    String yyyy = '';
    if (invoice.nextServiceDate != null) {
      dd = invoice.nextServiceDate!.day.toString().padLeft(2, '0');
      mm = invoice.nextServiceDate!.month.toString().padLeft(2, '0');
      yyyy = invoice.nextServiceDate!.year.toString();
    }

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          pw.Image(
            generatorImg,
            width: width,
            height: height,
            fit: pw.BoxFit.fill,
          ),
          // Generator Model / Make (line y: 306/388 = 0.789, x: 69 to 759)
          pw.Positioned(
            left: width * 0.030,
            top: height * 0.64,
            child: pw.SizedBox(
              width: width * 0.260,
              child: pw.Text(
                _safe(invoice.model),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
          // Engine Running Hours (line y: 306/388 = 0.789, x: 1061 to 1664)
          pw.Positioned(
            left: width * 0.415,
            top: height * 0.64,
            child: pw.SizedBox(
              width: width * 0.225,
              child: pw.Text(
                _safe(invoice.runningHour),
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
                maxLines: 1,
              ),
            ),
          ),
          // Next Service Date DD (line y: 306/388 = 0.789, x: 1921 to 2059)
          pw.Positioned(
            left: width * 0.742,
            top: height * 0.64,
            child: pw.SizedBox(
              width: width * 0.053,
              child: pw.Center(
                child: pw.Text(
                  dd,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _black,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          // Next Service Date MM (line y: 306/388 = 0.789, x: 2121 to 2258)
          pw.Positioned(
            left: width * 0.819,
            top: height * 0.64,
            child: pw.SizedBox(
              width: width * 0.053,
              child: pw.Center(
                child: pw.Text(
                  mm,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _black,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
          // Next Service Date YYYY (line y: 306/388 = 0.789, x: 2320 to 2522)
          pw.Positioned(
            left: width * 0.896,
            top: height * 0.64,
            child: pw.SizedBox(
              width: width * 0.078,
              child: pw.Center(
                child: pw.Text(
                  yyyy,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _black,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Items Table ────────────────────────────────────────────────────────

  static pw.Widget _buildItemsTable(Invoice invoice, double width) {
    const minRows = 7;
    const col1Width = 280.0;
    const col2Width = 74.0;
    const col3Width = 110.0;
    const col4Width = 110.0; // sum = 574.0

    // Keep table perfectly sized for A4 with 7 rows
    final rowHeight = invoice.items.length <= minRows
        ? 22.0
        : (154.0 / invoice.items.length).clamp(14.0, 22.0);

    // Header row
    final headerRow = pw.Container(
      height: 22,
      decoration: const pw.BoxDecoration(
        color: _yellow,
        border: pw.Border(
          bottom: pw.BorderSide(color: _black, width: 1.0),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: col1Width,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'Description of Goods / Services',
              style: _tableHeaderStyle,
            ),
          ),
          pw.Container(width: 1.0, color: _black),
          pw.Container(
            width: col2Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text('Qty', style: _tableHeaderStyle),
          ),
          pw.Container(width: 1.0, color: _black),
          pw.Container(
            width: col3Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text('Unit Price (GHC)', style: _tableHeaderStyle),
          ),
          pw.Container(width: 1.0, color: _black),
          pw.Container(
            width: col4Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text('Amount (GHC)', style: _tableHeaderStyle),
          ),
        ],
      ),
    );

    final rows = <pw.Widget>[headerRow];

    for (int i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      final isLast =
          (i == invoice.items.length - 1) && (invoice.items.length >= minRows);
      rows.add(_tableItemRow(
        col1Width: col1Width,
        col2Width: col2Width,
        col3Width: col3Width,
        col4Width: col4Width,
        height: rowHeight,
        description: item.description,
        qty: item.quantity > 0 ? item.quantity.toStringAsFixed(0) : '',
        price: _formatMoneyOrBlank(item.price),
        amount: _formatMoneyOrBlank(item.total),
        showBottomBorder: !isLast,
      ));
    }

    final needed = (minRows - invoice.items.length).clamp(0, minRows);
    for (int i = 0; i < needed; i++) {
      final isLast = (i == needed - 1);
      rows.add(_tableItemRow(
        col1Width: col1Width,
        col2Width: col2Width,
        col3Width: col3Width,
        col4Width: col4Width,
        height: rowHeight,
        description: '',
        qty: '',
        price: '',
        amount: '',
        showBottomBorder: !isLast,
      ));
    }

    return pw.Container(
      width: width,
      decoration: pw.BoxDecoration(
        color: _white,
        border: pw.Border.all(color: _yellow, width: 1.0),
      ),
      child: pw.Column(children: rows),
    );
  }

  static pw.Widget _tableItemRow({
    required double col1Width,
    required double col2Width,
    required double col3Width,
    required double col4Width,
    required double height,
    required String description,
    required String qty,
    required String price,
    required String amount,
    required bool showBottomBorder,
  }) {
    return pw.Container(
      height: height,
      decoration: pw.BoxDecoration(
        border: showBottomBorder
            ? const pw.Border(
                bottom: pw.BorderSide(color: _black, width: 0.5),
              )
            : null,
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: col1Width,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(description, style: _tableCellStyle, maxLines: 1),
          ),
          pw.Container(width: 1.0, color: _black),
          pw.Container(
            width: col2Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text(qty, style: _tableCellStyle, maxLines: 1),
          ),
          pw.Container(width: 1.0, color: _black),
          pw.Container(
            width: col3Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text(price, style: _tableCellStyle, maxLines: 1),
          ),
          pw.Container(width: 1.0, color: _black),
          pw.Container(
            width: col4Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text(amount, style: _tableCellStyle, maxLines: 1),
          ),
        ],
      ),
    );
  }

  // ── 6. Report/Remarks + Totals ────────────────────────────────────────────

  static pw.Widget _buildRemarksAndTotals(Invoice invoice, double width) {
    const boxHeight = 122.0;
    const leftWidth = 325.0;
    const rightWidth = 241.0; // 325 + 8 + 241 = 574.0

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildRemarksBox(_safe(invoice.jobDescription), leftWidth, boxHeight),
        pw.SizedBox(width: 8),
        _buildTotalsBox(invoice, rightWidth, boxHeight),
      ],
    );
  }

  static List<String> _splitRemarks(String remarks,
      {int maxLines = 5, int maxCharsPerLine = 82}) {
    if (remarks.trim().isEmpty) return [];
    final paragraphs = remarks.split('\n');
    final lines = <String>[];
    for (final p in paragraphs) {
      final words = p.trim().split(RegExp(r'\s+'));
      if (words.isEmpty || (words.length == 1 && words[0].isEmpty)) {
        lines.add('');
        if (lines.length >= maxLines) break;
        continue;
      }
      var current = '';
      for (final word in words) {
        if (word.isEmpty) continue;
        if (current.isEmpty) {
          current = word;
        } else if ((current.length + 1 + word.length) <= maxCharsPerLine) {
          current += ' $word';
        } else {
          lines.add(current);
          current = word;
          if (lines.length >= maxLines) break;
        }
      }
      if (current.isNotEmpty && lines.length < maxLines) {
        lines.add(current);
      }
      if (lines.length >= maxLines) break;
    }
    return lines;
  }

  static pw.Widget _buildRemarksBox(
      String remarks, double width, double height) {
    const headerHeight = 22.0;
    const lineCount = 5;
    final textLines =
        _splitRemarks(remarks, maxLines: lineCount, maxCharsPerLine: 82);

    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: _white,
        border: pw.Border.all(color: _yellow, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Yellow header bar
          pw.Container(
            height: headerHeight,
            decoration: const pw.BoxDecoration(
              color: _yellow,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(2.5),
                topRight: pw.Radius.circular(2.5),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            alignment: pw.Alignment.centerLeft,
            child: pw.Row(
              children: [
                _buildClipboardIcon(),
                pw.SizedBox(width: 6),
                pw.Text('Report / Remarks', style: _sectionTitleStyle),
              ],
            ),
          ),
          // Ruled notebook lines area with text aligned cleanly on grey lines
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4.0),
              child: pw.Column(
                children: List.generate(lineCount, (i) {
                  final lineText = i < textLines.length ? textLines[i] : '';
                  return pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(color: _lineGrey, width: 0.6),
                        ),
                      ),
                      alignment: pw.Alignment.bottomLeft,
                      padding: const pw.EdgeInsets.only(bottom: 2.0),
                      child: pw.Text(
                        lineText,
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: _black,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClipboardIcon() {
    return pw.Container(
      width: 12,
      height: 14,
      decoration: pw.BoxDecoration(
        color: _yellow,
        border: pw.Border.all(color: _black, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(width: 6, height: 1.0, color: _black),
          pw.SizedBox(height: 1.5),
          pw.Container(width: 6, height: 1.0, color: _black),
          pw.SizedBox(height: 1.5),
          pw.Container(width: 4, height: 1.0, color: _black),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalsBox(
      Invoice invoice, double width, double height) {
    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: _white,
        border: pw.Border.all(color: _yellow, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _totalRow(
            'Subtotal (GHC)',
            _formatMoney(invoice.itemsSubTotal),
          ),
          _totalRow(
            'Transportation (GHC)',
            _formatMoneyOrBlank(invoice.transportationAmount),
          ),
          _totalRow(
            'Labour (GHC)',
            _formatMoneyOrBlank(invoice.labourAmount),
          ),
          // Yellow highlighted row for TOTAL AMOUNT DUE
          pw.Container(
            height: 24,
            decoration: const pw.BoxDecoration(
              color: _yellow,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'TOTAL AMOUNT DUE (GHC)',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _black,
                    ),
                  ),
                ),
                pw.Container(
                  width: 76,
                  height: 18,
                  decoration: pw.BoxDecoration(
                    color: _white,
                    border: pw.Border.all(color: _borderGrey, width: 0.8),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    _formatMoney(invoice.grandTotal),
                    style: _grandTotalValueStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(label, style: _totalLabelStyle),
        ),
        pw.Container(
          width: 76,
          height: 18,
          decoration: pw.BoxDecoration(
            color: _white,
            border: pw.Border.all(color: _borderGrey, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _black,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ── 7. Signature Section ──────────────────────────────────────────────────

  static pw.Widget _buildSignatureSection(Invoice invoice, double width) {
    return pw.SizedBox(
      width: width,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Prepared By
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sigLine('Prepared By:', "Timo's Engineering Service"),
                pw.SizedBox(height: 6),
                _sigLine('Name:', _safe(invoice.managerName)),
                pw.SizedBox(height: 6),
                _sigLine('Signature:', ''),
              ],
            ),
          ),
          pw.SizedBox(width: 34),
          // Right: Customer Signature
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sigLine('Customer Signature:', ''),
                pw.SizedBox(height: 6),
                _sigLine('Name:', ''),
                pw.SizedBox(height: 6),
                _sigLine('Date:', ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sigLine(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(label, style: _fieldLabelStyle),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: pw.Container(
            height: 13,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _black, width: 0.8),
              ),
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _black,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 8. Footer ─────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.MemoryImage footerImg, double width) {
    // full_footer.png aspect ratio: 2965 / 368 = 8.057
    final height = width / 8.057;

    return pw.Image(
      footerImg,
      width: width,
      height: height,
      fit: pw.BoxFit.fill,
    );
  }

  // ── Public Methods ────────────────────────────────────────────────────────

  /// Print or preview in-app using the printing package.
  static Future<void> printPdf(Invoice invoice) async {
    final pdf = await buildPdf(invoice);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: '${invoice.invoiceNumber}.pdf',
      format: PdfPageFormat.a4,
      usePrinterSettings: false,
    );
  }

  /// Share PDF via OS share dialog / email / WhatsApp etc.
  static Future<void> share(Invoice invoice) async {
    final pdf = await buildPdf(invoice);
    final bytes = await pdf.save();

    final exportsDir = StorageService.instance.exportsDir;
    final filename = '${_sanitizeFilename(invoice.invoiceNumber)}.pdf';
    final tempFile = File('$exportsDir${Platform.pathSeparator}$filename');
    await tempFile.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(tempFile.path, mimeType: 'application/pdf')],
      subject: 'Invoice ${invoice.invoiceNumber}',
      text: 'Please find the invoice attached.',
    );
  }

  /// Save PDF — native file picker on desktop, share sheet on mobile.
  static Future<String?> savePdf(Invoice invoice) async {
    final pdf = await buildPdf(invoice);
    final bytes = await pdf.save();

    final clientName = _sanitizeFilename(invoice.clientName);
    final invoiceNo = _sanitizeFilename(invoice.invoiceNumber);
    final defaultFileName = '$clientName-$invoiceNo.pdf';

    if (Platform.isAndroid || Platform.isIOS) {
      final exportsDir = StorageService.instance.exportsDir;
      final outFile =
          File('$exportsDir${Platform.pathSeparator}$defaultFileName');
      await outFile.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(outFile.path, mimeType: 'application/pdf')],
        subject: 'Invoice ${invoice.invoiceNumber}',
        text: 'Please find the invoice attached.',
      );
      return outFile.path;
    }

    final FileSaveLocation? result = await getSaveLocation(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
      suggestedName: defaultFileName,
    );

    if (result == null) return null;

    final file = XFile.fromData(
      bytes,
      name: defaultFileName,
      mimeType: 'application/pdf',
    );
    await file.saveTo(result.path);
    return result.path;
  }
}
