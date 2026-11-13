import 'dart:io';
import 'dart:math' as math;
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

  /// The parts table is intentionally hidden from the current PDF layout.
  /// Keep its builder below because it is planned for a future report version.
  /// Set this to true when the business approves showing it again.
  static const _includePartsAndConsumablesSection = false;

  /// Borders for totals boxes and inner lines
  static const _borderGrey = PdfColor.fromInt(0xFFCCCCCC);

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

  static Future<pw.Document> buildPdf(
    Invoice invoice, {
    bool includeServiceReport = true,
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');

    // Preload all 5 high-resolution graphic assets
    final headerImg = await _loadHeader();
    final invoiceImg = await _loadInvoice();
    final customerImg = await _loadCustomer();
    final generatorImg = await _loadGenerator();
    final footerImg = await _loadFooter();

    final pageWidth = PdfPageFormat.a4.width;
    final pageHeight = PdfPageFormat.a4.height;
    const contentWidth = 574.0;
    const minRows = 10;

    // ── Compute section heights from asset aspect ratios ──────────────────
    final headerH = pageWidth / 5.9174;
    final footerH = pageWidth / 8.057;
    const bannerH = contentWidth / 10.5779;
    const customerH = contentWidth / 7.8248;
    const generatorH = contentWidth / 6.6925;
    const tableHeaderH = 22.0;
    const totalsNormal = 96.0;
    const totalsCompact = 92.0;
    const validityH = 30.0; // ~2 wrapped lines of text at 7.8pt
    const signatureH = 51.0; // 3 sig lines × (13pt + 6pt gap)

    // ── Compact mode: kick in when items exceed the normal minimum ────────
    final itemCount = invoice.items.length;
    final isCompact = itemCount > minRows;
    final gap = isCompact ? 3.0 : 5.0; // between sections
    final gapPost = isCompact ? 4.0 : 6.0; // after totals / validity
    final totalsH = isCompact ? totalsCompact : totalsNormal;
    final validityPadV = isCompact ? 4.0 : 6.0;

    // ── Row height: fills available space exactly, stays readable ─────────
    // Available = page height − footer − all fixed sections above/below table
    final fixedH = headerH
        + gap + bannerH
        + gap + customerH
        + gap + generatorH
        + gap + tableHeaderH // gap before table + table header row
        + gap + totalsH // gap after table rows + totals box
        + gapPost + validityH
        + gapPost + signatureH;

    final availableForRows = (pageHeight - footerH) - fixedH;
    final effectiveRows = itemCount > minRows ? itemCount : minRows;
    final rowHeight = (availableForRows / effectiveRows).clamp(12.0, 22.0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(
          children: [
            // ── Content column (header + body) ────────────────────────────
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── 1. Full-bleed Company Header ───────────────────────────
                pw.Image(
                  headerImg,
                  width: pageWidth,
                  height: headerH,
                  fit: pw.BoxFit.fill,
                ),

                // ── Body Elements with Horizontal Margins ──────────────────
                pw.Align(
                  alignment: pw.Alignment.topCenter,
                  child: pw.SizedBox(
                    width: contentWidth,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.SizedBox(height: gap),

                        // ── 2. INVOICE Banner ────────────────────────────────
                        _buildInvoiceBanner(
                          invoiceImg,
                          invoice,
                          dateFmt.format(invoice.date),
                          contentWidth,
                        ),
                        pw.SizedBox(height: gap),

                        // ── 3. Customer Details ──────────────────────────────
                        _buildCustomerSection(
                            customerImg, invoice, contentWidth),
                        pw.SizedBox(height: gap),

                        // ── 4. Generator Details ─────────────────────────────
                        _buildGeneratorDetails(
                            generatorImg, invoice, contentWidth),
                        pw.SizedBox(height: gap),

                        // ── 5. Items Table ───────────────────────────────────
                        _buildItemsTable(invoice, contentWidth,
                            rowHeight: rowHeight, minRows: minRows),
                        pw.SizedBox(height: gap),

                        // ── 6. Invoice Totals ────────────────────────────────
                        _buildTotalsBox(invoice, contentWidth, totalsH),
                        pw.SizedBox(height: gapPost),

                        // ── 7. Invoice Validity Notice ───────────────────────
                        _buildValidityNotice(invoice, dateFmt, contentWidth,
                            verticalPadding: validityPadV),
                        pw.SizedBox(height: gapPost),

                        // ── 8. Signature Section ─────────────────────────────
                        _buildSignatureSection(invoice, contentWidth),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Footer pinned permanently to the bottom of the page ───────
            pw.Positioned(
              bottom: 0,
              left: 0,
              child: _buildFooter(footerImg, pageWidth),
            ),
          ],
        ),
      ),
    );

    if (includeServiceReport) {
      // The report is deliberately a separate, paginated section so the
      // financial invoice remains clean while detailed service notes can flow
      // onto as many branded report pages as necessary.
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          header: (context) {
            // Page 1 is always the financial invoice.
            // Page 2 is the first page of the service report (full branding).
            // Page 3+ are continuation pages (compact header to maximize content room).
            if (context.pageNumber <= 2) {
              return pw.Column(
                children: [
                  pw.Image(
                    headerImg,
                    width: pageWidth,
                    height: pageWidth / 3.9174,
                    fit: pw.BoxFit.fill,
                  ),
                  _buildServiceReportHeading(),
                ],
              );
            }
            return _buildServiceReportContinuationHeading(
              headerImg,
              invoice,
              pageWidth,
            );
          },
          footer: (_) => _buildFooter(footerImg, pageWidth),
          build: (_) => _buildServiceReportContent(
            invoice,
            dateFmt,
            horizontalMargin: (pageWidth - contentWidth) / 2,
          ),
        ),
      );
    }

    return pdf;
  }

  // ── 2. INVOICE Banner ─────────────────────────────────────────────────────

  static pw.Widget _buildInvoiceBanner(
    pw.MemoryImage bannerImg,
    Invoice invoice,
    String dateStr,
    double width,
  ) {
    // invoice.png aspect ratio: 2581 / 244 = 10.5779
    final height = width / 13.5779;

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        fit: pw.StackFit.expand,
        children: [
          pw.Image(
            bannerImg,
            fit: pw.BoxFit.fill,
          ),
          // Invoice No overlay (line y: 86/244 = 0.352, x: 1821 to 2522 in invoice.png)
          pw.Positioned(
            left: width * 0.710,
            top: height * 0.10,
            child: pw.SizedBox(
              width: width * 0.265,
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
          // Date overlay (line y: 195/244 = 0.799, x: 1821 to 2522 in invoice.png)
          pw.Positioned(
            left: width * 0.710,
            top: height * 0.65,
            child: pw.SizedBox(
              width: width * 0.265,
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
    final height = width / 9.8248;

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        fit: pw.StackFit.expand,
        children: [
          pw.Image(
            customerImg,
            fit: pw.BoxFit.fill,
          ),
          // Customer Name (line 1 left, y: 98/331 = 0.296, x: 515 to 1558)
          pw.Positioned(
            left: width * 0.070,
            top: height * 0.37,
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
          // Bill To (line 1 right, y: 98/331 = 0.296, x: 1829 to 2538)
          pw.Positioned(
            left: width * 0.570,
            top: height * 0.37,
            child: pw.SizedBox(
              width: width * 0.265,
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
          // Customer Address (line 2, y: 190/331 = 0.574, x: 515 to 2538)
          pw.Positioned(
            left: width * 0.095,
            top: height * 0.73,
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
          // Customer Phone (line 3, y: 283/331 = 0.855, x: 515 to 2538)
          pw.Positioned(
            left: width * 0.570,
            top: height * 0.73,
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
    // generator_details.png aspect ratio: 2590 / 387 = 6.6925
    final height = width / 9.6925;

    String nextServiceDateStr = '';
    if (invoice.nextServiceDate != null) {
      final d = invoice.nextServiceDate!;
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yyyy = d.year.toString();
      nextServiceDateStr = '$dd / $mm / $yyyy';
    }

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        fit: pw.StackFit.expand,
        children: [
          pw.Image(
            generatorImg,
            fit: pw.BoxFit.fill,
          ),
          // Generator Model / Make (line y: 305/387 = 0.788, x: 84 to 650)
          pw.Positioned(
            left: width * 0.030,
            top: height * 0.70,
            child: pw.SizedBox(
              width: width * 0.216,
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
          // Engine Running Hours (line y: 305/387 = 0.788, x: 1099 to 1695)
          pw.Positioned(
            left: width * 0.422,
            top: height * 0.70,
            child: pw.SizedBox(
              width: width * 0.228,
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
          // Next Service Date (unified single line: y: 305/387 = 0.788, x: 2059 to 2507)
          pw.Positioned(
            left: width * 0.755,
            top: height * 0.70,
            child: pw.SizedBox(
              width: width * 0.173,
              child: pw.Center(
                child: pw.Text(
                  nextServiceDateStr,
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

  static pw.Widget _buildItemsTable(
    Invoice invoice,
    double width, {
    required double rowHeight,
    required int minRows,
  }) {
    const col1Width = 330.0;
    const col2Width = 60.0;
    const col3Width = 90.0;
    const col4Width = 94.0; // sum = 574.0

    // Header row
    final headerRow = pw.Container(
      height: 22,
      decoration: pw.BoxDecoration(
        color: _yellow,
        border: pw.Border.all(color: _yellow, width: 1.0),
        borderRadius: const pw.BorderRadius.only(
          topLeft: pw.Radius.circular(2.5),
          topRight: pw.Radius.circular(2.5),
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
          pw.Container(width: 1.0, color: _white),
          pw.Container(
            width: col2Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text('Qty', style: _tableHeaderStyle),
          ),
          pw.Container(width: 1.0, color: _white),
          pw.Container(
            width: col3Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text('Unit Price (GHC)', style: _tableHeaderStyle),
          ),
          pw.Container(width: 1.0, color: _white),
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
                bottom: pw.BorderSide(color: _yellow, width: 0.6),
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
          pw.Container(width: 1.0, color: _yellow),
          pw.Container(
            width: col2Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text(qty, style: _tableCellStyle, maxLines: 1),
          ),
          pw.Container(width: 1.0, color: _yellow),
          pw.Container(
            width: col3Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text(price, style: _tableCellStyle, maxLines: 1),
          ),
          pw.Container(width: 1.0, color: _yellow),
          pw.Container(
            width: col4Width - 1.0,
            alignment: pw.Alignment.center,
            child: pw.Text(amount, style: _tableCellStyle, maxLines: 1),
          ),
        ],
      ),
    );
  }

  // ── Service Report (second part) ──────────────────────────────────────────────

  static List<pw.Widget> _buildServiceReportContent(
    Invoice invoice,
    DateFormat dateFmt, {
    required double horizontalMargin,
  }) {
    final workPerformed = _safe(invoice.jobDescription, '');
    final observations = _safe(invoice.observations, '');
    final recommendations = _safe(invoice.recommendations, '');

    pw.Widget content(pw.Widget child) => pw.Padding(
          padding: pw.EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: child,
        );

    return [
      pw.SizedBox(height: 8),
      content(_buildReportReferenceCard(invoice, dateFmt)),
      pw.SizedBox(height: 8),
      content(_buildReportNarrative(
        'WORK PERFORMED',
        workPerformed,
      )),
      pw.SizedBox(height: 7),
      content(_buildReportNarrative(
        'OBSERVATIONS / CONDITION FOUND',
        observations,
      )),
      pw.SizedBox(height: 7),
      content(_buildReportNarrative(
        'RECOMMENDATIONS / NEXT ACTIONS',
        recommendations,
      )),
      // Do not remove this block: the parts table is retained for a future
      // report layout, but is intentionally excluded from PDFs for now.
      if (_includePartsAndConsumablesSection) ...[
        pw.SizedBox(height: 8),
        content(_buildPartsUsedSection(invoice)),
      ],
      pw.SizedBox(height: 10),
      content(_KeepTogether(child: _buildServiceReportSignOff(invoice))),
    ];
  }

  static pw.Widget _buildReportReferenceCard(
      Invoice invoice, DateFormat dateFmt) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFFF8D8),
        border: pw.Border(
          top: pw.BorderSide(color: _yellow),
          right: pw.BorderSide(color: _yellow),
          bottom: pw.BorderSide(color: _yellow),
          left: pw.BorderSide(color: _yellow),
        ),
      ),
      padding: const pw.EdgeInsets.all(9),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              _reportReference('INVOICE NO.', invoice.invoiceNumber),
              _reportReference('SERVICE DATE', dateFmt.format(invoice.date)),
              _reportReference(
                  'NEXT SERVICE',
                  invoice.nextServiceDate == null
                      ? 'Not scheduled'
                      : dateFmt.format(invoice.nextServiceDate!)),
            ],
          ),
          pw.SizedBox(height: 7),
          pw.Row(
            children: [
              _reportReference(
                  'CLIENT', _safe(invoice.billTo, invoice.clientName)),
              _reportReference(
                  'GENERATOR / MODEL', _safe(invoice.model, 'Not recorded')),
              _reportReference(
                  'RUNNING HOURS', _safe(invoice.runningHour, 'Not recorded')),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildServiceReportHeading() {
    return pw.Container(
      color: _black,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: pw.Center(
        child: pw.Text(
          'GENERATOR SERVICE REPORT & TECHNICAL REMARKS',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: _white,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildServiceReportContinuationHeading(
    pw.MemoryImage headerImg,
    Invoice invoice,
    double width,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Image(
          headerImg,
          width: width,
          height: width / 3.9174,
          fit: pw.BoxFit.fill,
        ),
        pw.Container(
          color: _black,
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GENERATOR SERVICE REPORT & TECHNICAL REMARKS (Cont.)',
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Text(
                'Invoice: ${_safe(invoice.invoiceNumber)}',
                style: pw.TextStyle(
                  color: _yellow,
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          height: 2.5,
          color: _yellow,
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _reportReference(String label, String value) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 6.8,
                    fontWeight: pw.FontWeight.bold,
                    color: _black)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                maxLines: 2,
                style: pw.TextStyle(
                    fontSize: 8.3,
                    fontWeight: pw.FontWeight.bold,
                    color: _black)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildReportNarrative(String title, String text) {
    final cleanText = text.trim();
    return _KeepTogether(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borderGrey, width: 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: _yellow,
              alignment: pw.Alignment.center,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
              child: pw.Text(
                title,
                textAlign: pw.TextAlign.center,
                style: _sectionTitleStyle,
              ),
            ),
            _RuledLines(
              child: pw.Text(
                cleanText,
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(
                  fontSize: _RuledLines.fontSize,
                  color: _black,
                  lineSpacing: _RuledLines.lineSpacing,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPartsUsedSection(Invoice invoice) {
    final items = invoice.items
        .where((item) =>
            item.description.trim().isNotEmpty ||
            item.quantity > 0 ||
            item.price > 0)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: _black,
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: pw.Text(
            'PARTS AND CONSUMABLES USED',
            style: pw.TextStyle(
              color: _white,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _borderGrey, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(34),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _yellow),
              children: [
                _partsCell('NO.', bold: true),
                _partsCell('DESCRIPTION', bold: true),
                _partsCell('QTY', bold: true, align: pw.TextAlign.center),
              ],
            ),
            if (items.isEmpty)
              pw.TableRow(children: [
                _partsCell(''),
                _partsCell('No parts or consumables recorded.'),
                _partsCell(''),
              ])
            else
              ...items.asMap().entries.map(
                    (entry) => pw.TableRow(children: [
                      _partsCell('${entry.key + 1}',
                          align: pw.TextAlign.center),
                      _partsCell(
                          _safe(entry.value.description, 'Unnamed item')),
                      _partsCell(
                          entry.value.quantity.toStringAsFixed(
                              entry.value.quantity % 1 == 0 ? 0 : 2),
                          align: pw.TextAlign.center),
                    ]),
                  ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _partsCell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        maxLines: 2,
        style: pw.TextStyle(
          fontSize: 8.2,
          color: _black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildServiceReportSignOff(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TECHNICIAN SIGN-OFF', style: _sectionTitleStyle),
              pw.SizedBox(height: 7),
              _sigLine('Technician:',
                  _safe(invoice.technicianName, invoice.managerName)),
              pw.SizedBox(height: 8),
              _sigLine('Signature:', ''),
              pw.SizedBox(height: 8),
              _sigLine('Date:', ''),
            ],
          ),
        ),
        pw.SizedBox(width: 38),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CLIENT ACCEPTANCE', style: _sectionTitleStyle),
              pw.SizedBox(height: 7),
              _sigLine('Representative:', _safe(invoice.representativeName)),
              pw.SizedBox(height: 8),
              _sigLine('Signature:', ''),
              pw.SizedBox(height: 8),
              _sigLine('Date:', ''),
            ],
          ),
        ),
      ],
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

  // ── 7. Invoice Validity Notice ────────────────────────────────────────────

  static pw.Widget _buildValidityNotice(
      Invoice invoice, DateFormat dateFmt, double width,
      {double verticalPadding = 6.0}) {
    final expiryDate = DateTime(
      invoice.date.year,
      invoice.date.month + 1,
      invoice.date.day,
    );
    final expiryStr = dateFmt.format(expiryDate);
    final boldStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);

    return pw.Container(
      width: width,
      padding: pw.EdgeInsets.symmetric(horizontal: 10, vertical: verticalPadding),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFF8D8),
        border: pw.Border.all(color: _yellow, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 7.8, color: _black),
          children: [
            pw.TextSpan(
              text: 'INVOICE VALIDITY NOTICE: ',
              style: boldStyle,
            ),
            const pw.TextSpan(
              text:
                  'This invoice is valid for 30 days from the date of issue and expires on ',
            ),
            pw.TextSpan(
              text: expiryStr,
              style: boldStyle,
            ),
            const pw.TextSpan(
              text:
                  '. Upon expiry, a new invoice will be issued with an updated terms.',
            ),
          ],
        ),
      ),
    );
  }

  // ── 8. Signature Section ──────────────────────────────────────────────────

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
                _sigLine('Name:', _safe(invoice.clientName)),
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
  static Future<void> printPdf(
    Invoice invoice, {
    bool includeServiceReport = true,
  }) async {
    final pdf =
        await buildPdf(invoice, includeServiceReport: includeServiceReport);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: '${invoice.invoiceNumber}.pdf',
      format: PdfPageFormat.a4,
      usePrinterSettings: false,
    );
  }

  /// Share PDF via OS share dialog / email / WhatsApp etc.
  static Future<void> share(
    Invoice invoice, {
    bool includeServiceReport = true,
  }) async {
    final pdf =
        await buildPdf(invoice, includeServiceReport: includeServiceReport);
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
  static Future<String?> savePdf(
    Invoice invoice, {
    bool includeServiceReport = true,
  }) async {
    final pdf =
        await buildPdf(invoice, includeServiceReport: includeServiceReport);
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

/// Prevents a widget (such as a narrative section or signature block)
/// from splitting across pages, keeping it as an unbroken block.
/// If content exceeds typical page height (e.g. > 550pt), it gracefully allows spanning.
class _KeepTogether extends pw.SingleChildWidget {
  _KeepTogether({required pw.Widget child}) : super(child: child);

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }

  @override
  bool get canSpan =>
      box != null &&
      box!.height > 550 &&
      child is pw.SpanningWidget &&
      (child as pw.SpanningWidget).canSpan;

  @override
  bool get hasMoreWidgets => canSpan;
}

/// Renders horizontal grey ruled lines across narrative sections (lined paper style).
/// Body text at fontSize 10 is harmoniously aligned above each line, and the
/// container displays a minimum of [minLines] ruled rows (default 5) even when empty.
class _RuledLines extends pw.SingleChildWidget {
  static const int minLines = 5;
  static const double lineHeight = 19.0;
  static const double fontSize = 10.0;
  // Helvetica height factor in package:pdf is 1.156.
  // Using lineHeight - fontHeight guarantees an exact 19.0pt advance per line with 0.0 drift.
  static const double fontHeight = fontSize * 1.156;
  static const double lineSpacing = lineHeight - fontHeight;
  static const double topOffset = 5.6;
  static const PdfColor lineColor = PdfColor.fromInt(0xFFCCCCCC);
  static const double lineWidth = 0.6;
  static const double horizontalPadding = 9.0;

  _RuledLines({required pw.Widget child}) : super(child: child);

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    double childWidth = 0.0;
    double childHeight = 0.0;

    if (child != null) {
      final innerConstraints = constraints.deflate(
        const pw.EdgeInsets.symmetric(horizontal: horizontalPadding),
      );
      child!.layout(context, innerConstraints, parentUsesSize: true);
      childWidth = child!.box?.width ?? 0.0;
      childHeight = child!.box?.height ?? 0.0;
    }

    // Compute line count using the exact font height to prevent any fractional drift
    final textLines = childHeight > 0
        ? ((childHeight + (lineHeight - fontHeight)) / lineHeight).round()
        : 0;
    final totalLines = math.max(minLines, textLines);
    final totalHeight = totalLines * lineHeight;

    final resolvedWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : childWidth + horizontalPadding * 2;

    box = PdfRect(0, 0, resolvedWidth, totalHeight);

    // Shifts text downward so baselines sit consistently close to the ruled line beneath,
    // and comfortably away from the line above, on every single row without drift.
    if (child?.box != null) {
      child!.box = PdfRect(
        horizontalPadding,
        totalHeight - childHeight - topOffset,
        childWidth,
        childHeight,
      );
    }
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);

    if (box != null) {
      context.canvas
        ..setStrokeColor(lineColor)
        ..setLineWidth(lineWidth);

      // In PDF coordinates, box!.top is the top of this widget, box!.bottom is 0.
      // Draw horizontal ruled lines at intervals of [lineHeight] from the top down.
      for (var y = box!.top - lineHeight;
          y > box!.bottom + 1.0;
          y -= lineHeight) {
        context.canvas
          ..drawLine(box!.left, y, box!.right, y)
          ..strokePath();
      }
    }

    paintChild(context);
  }
}
