import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../data/datasources/storage_service.dart';
import '../../../data/models/invoice.dart';
import '../../../core/utils/currency_formatter.dart';

class PdfService {
  PdfService._();

  // ── Colours ───────────────────────────────────────────────────────────────

  /// Exact yellow from the design (#FFCC00 / gold-yellow)
  static const _yellow = PdfColor.fromInt(0xFFFFCC00);
  static const _black = PdfColors.black;
  static const _white = PdfColors.white;

  /// Very light grey for the remarks/totals box borders
  static const _borderGrey = PdfColor.fromInt(0xFFBBBBBB);

  /// Near-black for the INVOICE banner background
  static const _nearBlack = PdfColor.fromInt(0xFF1A1A1A);

  /// Medium grey for italic / secondary text
  static const _medGrey = PdfColor.fromInt(0xFF555555);

  // ── Text Styles ───────────────────────────────────────────────────────────

  static final _companyNameStyle = pw.TextStyle(
    fontSize: 22,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static final _companyServiceStyle = pw.TextStyle(
    fontSize: 15,
    fontWeight: pw.FontWeight.bold,
    color: _yellow,
  );
  static final _taglineStyle = pw.TextStyle(
    fontSize: 7.5,
    fontStyle: pw.FontStyle.italic,
    color: _black,
  );
  static final _invoiceBannerStyle = pw.TextStyle(
    fontSize: 36,
    fontWeight: pw.FontWeight.bold,
    color: _white,
  );
  static final _bannerFieldLabelStyle = pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static final _sectionBarStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static final _fieldLabelStyle = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static const _fieldValueStyle = pw.TextStyle(fontSize: 8.5);
  static final _tableHeaderStyle = pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static const _tableCellStyle = pw.TextStyle(fontSize: 8.5);
  static final _totalLabelStyle = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static final _grandTotalStyle = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static final _noVatStyle = pw.TextStyle(
    fontSize: 7.5,
    fontStyle: pw.FontStyle.italic,
    color: _medGrey,
  );
  static final _footerThankYouStyle = pw.TextStyle(
    fontSize: 9.5,
    fontStyle: pw.FontStyle.italic,
    color: _black,
  );
  static final _contactPhoneStyle = pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static final _contactLabelStyle = pw.TextStyle(
    fontSize: 7.5,
    fontWeight: pw.FontWeight.bold,
    color: _black,
  );
  static const _contactValueStyle = pw.TextStyle(fontSize: 7.5);

  // ── Image Cache ───────────────────────────────────────────────────────────

  static pw.MemoryImage? _headerLogoCache;
  static pw.MemoryImage? _footerLogoCache;

  static Future<pw.MemoryImage> _loadHeaderLogo() async {
    _headerLogoCache ??= pw.MemoryImage(
      (await rootBundle.load('assets/new_logo(header).png'))
          .buffer
          .asUint8List(),
    );
    return _headerLogoCache!;
  }

  static Future<pw.MemoryImage> _loadFooterLogo() async {
    _footerLogoCache ??= pw.MemoryImage(
      (await rootBundle.load('assets/new_logo(footer).png'))
          .buffer
          .asUint8List(),
    );
    return _footerLogoCache!;
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

    final headerLogo = await _loadHeaderLogo();
    final footerLogo = await _loadFooterLogo();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. Company Header ──────────────────────────────────────────
            _buildCompanyHeader(headerLogo),
            pw.SizedBox(height: 6),

            // ── 2. INVOICE Banner ─────────────────────────────────────────
            _buildInvoiceBanner(invoice, dateFmt.format(invoice.date)),
            pw.SizedBox(height: 6),

            // ── 3. Customer Details ───────────────────────────────────────
            _buildCustomerSection(invoice),
            pw.SizedBox(height: 6),

            // ── 4. Generator Details ──────────────────────────────────────
            _buildGeneratorDetails(invoice),
            pw.SizedBox(height: 6),

            // ── 5. Items Table ────────────────────────────────────────────
            _buildItemsTable(invoice),
            pw.SizedBox(height: 6),

            // ── 6. Report/Remarks + Totals ────────────────────────────────
            _buildRemarksAndTotals(invoice),
            pw.SizedBox(height: 8),

            // ── 7. Signature Section ──────────────────────────────────────
            _buildSignatureSection(invoice),

            pw.Spacer(),

            // ── 8. Footer ─────────────────────────────────────────────────
            _buildFooter(footerLogo),
          ],
        ),
      ),
    );

    return pdf;
  }

  // ── 1. Company Header ─────────────────────────────────────────────────────
  //
  // Layout (left → right):
  //   [TE circle logo] | [Company name + SERVICE + tagline] | [vertical line] | [Phone / Email / Bank]

  static pw.Widget _buildCompanyHeader(pw.MemoryImage logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // TE logo
        pw.SizedBox(
          width: 78,
          height: 78,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 10),

        // Company name block
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text("TIMO'S ENGINEERING", style: _companyNameStyle),
              // "=== SERVICE ===" row
              pw.Row(
                children: [
                  pw.Container(width: 36, height: 1.8, color: _yellow),
                  pw.SizedBox(width: 5),
                  pw.Text('SERVICE', style: _companyServiceStyle),
                  pw.SizedBox(width: 5),
                  pw.Container(width: 36, height: 1.8, color: _yellow),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Powering Your World, One Generator at a Time.',
                style: _taglineStyle,
              ),
            ],
          ),
        ),

        // Vertical divider
        pw.Container(
          width: 0.8,
          height: 78,
          color: _borderGrey,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10),
        ),

        // Contact panel
        pw.SizedBox(
          width: 168,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // Phone
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  _circleIcon('T'), // telephone placeholder circle
                  pw.SizedBox(width: 5),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Phone:', style: _contactLabelStyle),
                      pw.Text('0593199191', style: _contactPhoneStyle),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              // Email
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _circleIcon('E'),
                  pw.SizedBox(width: 5),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Email:', style: _contactLabelStyle),
                      pw.Text(
                        "timo'sengineeringservices@gmail.com",
                        style: _contactValueStyle,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              // Bank Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _circleIcon('B'),
                  pw.SizedBox(width: 5),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bank Details:', style: _contactLabelStyle),
                      pw.Text('Bank:        GCB', style: _contactValueStyle),
                      pw.Text('Name:       Bright Atiemo Amoani',
                          style: _contactValueStyle),
                      pw.Text('Account No.: 6191010129078',
                          style: _contactValueStyle),
                      pw.Text('Branch:      Ahinsan',
                          style: _contactValueStyle),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Small circle badge used as icon placeholder (T=phone, E=email, B=bank)
  /// since emoji glyphs are unreliable in PDF rendering.
  static pw.Widget _circleIcon(String letter) {
    return pw.Container(
      width: 13,
      height: 13,
      decoration: const pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        color: _yellow,
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        letter,
        style: pw.TextStyle(
          fontSize: 6,
          fontWeight: pw.FontWeight.bold,
          color: _black,
        ),
      ),
    );
  }

  // ── 2. INVOICE Banner ─────────────────────────────────────────────────────
  //
  // Left black box: "INVOICE" bold white text, with a yellow diagonal wedge
  // on the right edge bleeding into the right yellow panel.
  // Right yellow panel: Invoice No. and Date fields.

  static pw.Widget _buildInvoiceBanner(Invoice invoice, String dateStr) {
    const bannerHeight = 52.0;
    const blackWidth = 230.0;

    return pw.SizedBox(
      height: bannerHeight,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Black "INVOICE" panel
          pw.Stack(
            children: [
              pw.Container(
                width: blackWidth,
                color: _nearBlack,
              ),
              // Yellow diagonal slash on right — approximated as a right-aligned
              // yellow strip; true skew not natively supported in pw.Stack
              pw.Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: pw.Container(width: 22, color: _yellow),
              ),
              // INVOICE text centred in the black area
              pw.Positioned.fill(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 22),
                  child: pw.Center(
                    child: pw.Text('INVOICE', style: _invoiceBannerStyle),
                  ),
                ),
              ),
            ],
          ),

          // Yellow right panel: Invoice No & Date
          pw.Expanded(
            child: pw.Container(
              color: _yellow,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _bannerField('Invoice No.:', _safe(invoice.invoiceNumber)),
                  pw.SizedBox(height: 8),
                  _bannerField('Date:', dateStr),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _bannerField(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(label, style: _bannerFieldLabelStyle),
        pw.SizedBox(width: 8),
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
              child: pw.Text(value,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  )),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Customer Details ───────────────────────────────────────────────────
  //
  // Rounded-corner bordered box.
  // Left ~60%: Customer Name / Address / Phone (each with underline field)
  // Right ~40%: Bill To (single underline field)

  static pw.Widget _buildCustomerSection(Invoice invoice) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left column
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _underlineField('Customer Name:', _safe(invoice.clientName)),
                pw.SizedBox(height: 5),
                _underlineField('Customer Address:', _safe(invoice.address)),
                pw.SizedBox(height: 5),
                _underlineField('Customer Phone:', _safe(invoice.phone)),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Right column
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _underlineField('Bill To:', _safe(invoice.billTo)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _underlineField(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(label, style: _fieldLabelStyle),
        pw.SizedBox(width: 5),
        pw.Expanded(
          child: pw.Container(
            height: 13,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _black, width: 0.5),
              ),
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(value, style: _fieldValueStyle),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Generator Details ──────────────────────────────────────────────────
  //
  // Yellow section header bar (no emoji — uses text label).
  // Three columns separated by vertical lines:
  //   Generator Model / Make | Engine Running Hours (+ "hrs") | Next Service Date (DD/MM/YYYY)

  static pw.Widget _buildGeneratorDetails(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Yellow header bar
        pw.Container(
          color: _yellow,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Text('  Generator Details', style: _sectionBarStyle),
        ),

        // Detail columns
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _borderGrey, width: 0.8),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Column 1: Generator Model / Make
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Generator Model / Make:',
                          style: _fieldLabelStyle),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        height: 14,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom:
                                pw.BorderSide(color: _black, width: 0.5),
                          ),
                        ),
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(_safe(invoice.model),
                              style: _fieldValueStyle),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Vertical divider
              pw.Container(width: 0.8, color: _borderGrey),

              // Column 2: Engine Running Hours
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Engine Running Hours:',
                          style: _fieldLabelStyle),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Expanded(
                            child: pw.Container(
                              height: 14,
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(
                                      color: _black, width: 0.5),
                                ),
                              ),
                              child: pw.Align(
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Text(_safe(invoice.runningHour),
                                    style: _fieldValueStyle),
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text('hrs',
                              style:
                                  const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Vertical divider
              pw.Container(width: 0.8, color: _borderGrey),

              // Column 3: Next Service Date
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Next Service Date:',
                          style: _fieldLabelStyle),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          _serviceDateBox(
                              invoice.nextServiceDate != null
                                  ? invoice.nextServiceDate!.day
                                      .toString()
                                      .padLeft(2, '0')
                                  : '',
                              'DD'),
                          pw.Text(' / ',
                              style: const pw.TextStyle(fontSize: 8)),
                          _serviceDateBox(
                              invoice.nextServiceDate != null
                                  ? invoice.nextServiceDate!.month
                                      .toString()
                                      .padLeft(2, '0')
                                  : '',
                              'MM'),
                          pw.Text(' / ',
                              style: const pw.TextStyle(fontSize: 8)),
                          _serviceDateBox(
                              invoice.nextServiceDate != null
                                  ? invoice.nextServiceDate!.year
                                      .toString()
                                  : '',
                              'YYYY'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _serviceDateBox(String value, String sub) {
    final isYear = sub == 'YYYY';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: isYear ? 32 : 20,
          height: 14,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _black, width: 0.5),
            ),
          ),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(value,
              style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Text(sub,
            style: const pw.TextStyle(fontSize: 5.5, color: _medGrey)),
      ],
    );
  }

  // ── 5. Items Table ────────────────────────────────────────────────────────
  //
  // Yellow header row.
  // All data rows: white background, thin bottom border only.
  // 4 columns: Description (wide) | Qty | Unit Price (GH₵) | Amount (GH₵)
  // Minimum 7 blank rows shown.

  static pw.Widget _buildItemsTable(Invoice invoice) {
    const minRows = 7;

    // Header
    final header = pw.Container(
      color: _yellow,
      child: pw.Row(
        children: [
          _tCell('Description of Goods / Services', 0,
              style: _tableHeaderStyle,
              expand: true,
              center: false,
              padV: 6),
          _tCell('Qty', 42,
              style: _tableHeaderStyle, center: true, padV: 6),
          _tCell('Unit Price (GH\u20b5)', 82,
              style: _tableHeaderStyle, center: true, padV: 6),
          _tCell('Amount (GH\u20b5)', 82,
              style: _tableHeaderStyle, center: true, padV: 6),
        ],
      ),
    );

    final rows = <pw.Widget>[header];

    for (int i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      rows.add(_dataRow(
        description: item.description,
        qty: item.quantity > 0 ? item.quantity.toStringAsFixed(0) : '',
        price: _formatMoneyOrBlank(item.price),
        amount: _formatMoneyOrBlank(item.total),
      ));
    }

    final needed = (minRows - invoice.items.length).clamp(0, minRows);
    for (int i = 0; i < needed; i++) {
      rows.add(_dataRow(description: '', qty: '', price: '', amount: ''));
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 0.8),
      ),
      child: pw.Column(children: rows),
    );
  }

  static pw.Widget _dataRow({
    required String description,
    required String qty,
    required String price,
    required String amount,
  }) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _white,
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderGrey, width: 0.4),
        ),
      ),
      child: pw.Row(
        children: [
          _tCell(description, 0,
              style: _tableCellStyle, expand: true, center: false),
          _tCell(qty, 42, style: _tableCellStyle, center: true),
          _tCell(price, 82, style: _tableCellStyle, center: true),
          _tCell(amount, 82, style: _tableCellStyle, center: true),
        ],
      ),
    );
  }

  static pw.Widget _tCell(
    String text,
    double width, {
    pw.TextStyle? style,
    bool center = false,
    bool expand = false,
    double padV = 5,
  }) {
    final content = pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: padV),
      child: pw.Text(
        text,
        style: style ?? _tableCellStyle,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
    if (expand) return pw.Expanded(child: content);
    return pw.SizedBox(width: width, child: content);
  }

  // ── 6. Report/Remarks + Totals ────────────────────────────────────────────
  //
  // Left (~55%): Yellow "Report / Remarks" header bar + white lined area.
  // Right (~45%): Totals box — 4 rows (Subtotal/Transportation/Labour/Other)
  //   each with a right-side value box (white, black border).
  //   Then a full-width yellow "TOTAL AMOUNT DUE" row with value box.
  //   Then italic "No VAT Included" centred below.

  static pw.Widget _buildRemarksAndTotals(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Report / Remarks
        pw.Expanded(
          flex: 55,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Yellow header
              pw.Container(
                color: _yellow,
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                child:
                    pw.Text('  Report / Remarks', style: _sectionBarStyle),
              ),
              // Lined text area
              pw.Container(
                height: 108,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderGrey, width: 0.8),
                ),
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      _safe(invoice.jobDescription),
                      style: _tableCellStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 8),

        // Totals box
        pw.Expanded(
          flex: 45,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderGrey, width: 0.8),
            ),
            child: pw.Column(
              children: [
                _totalRow('Subtotal (GH\u20b5)',
                    _formatMoney(invoice.itemsSubTotal)),
                _totalRow('Transportation (GH\u20b5)',
                    _formatMoneyOrBlank(invoice.transportationAmount)),
                _totalRow('Labour (GH\u20b5)',
                    _formatMoneyOrBlank(invoice.labourAmount)),
                _totalRow('Other Charges (GH\u20b5)',
                    _formatMoneyOrBlank(invoice.otherChargesAmount)),

                // TOTAL AMOUNT DUE — yellow highlighted row
                pw.Container(
                  color: _yellow,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text('TOTAL AMOUNT DUE (GH\u20b5)',
                            style: _grandTotalStyle),
                      ),
                      pw.Container(
                        width: 68,
                        height: 16,
                        decoration: pw.BoxDecoration(
                          color: _white,
                          border: pw.Border.all(
                              color: _black, width: 0.6),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          _formatMoney(invoice.grandTotal),
                          style: _grandTotalStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // No VAT Included
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Center(
                    child: pw.Text('No VAT Included', style: _noVatStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _totalRow(String label, String value) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderGrey, width: 0.5),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label, style: _totalLabelStyle),
          ),
          pw.Container(
            width: 68,
            height: 14,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderGrey, width: 0.5),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(value,
                style: _tableCellStyle,
                textAlign: pw.TextAlign.center),
          ),
        ],
      ),
    );
  }

  // ── 7. Signature Section ──────────────────────────────────────────────────
  //
  // Two columns:
  //   Left:  Prepared By / Name / Signature  (each with underline)
  //   Right: Customer Signature / Name / Date (each with underline)

  static pw.Widget _buildSignatureSection(Invoice invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Prepared By
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sigLine('Prepared By:', ''),
              pw.SizedBox(height: 5),
              _sigLine('Name:', _safe(invoice.managerName)),
              pw.SizedBox(height: 5),
              _sigLine('Signature:', ''),
            ],
          ),
        ),
        pw.SizedBox(width: 24),
        // Right: Customer Signature
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sigLine('Customer Signature:', ''),
              pw.SizedBox(height: 5),
              _sigLine('Name:', ''),
              pw.SizedBox(height: 5),
              _sigLine('Date:', ''),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sigLine(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(label, style: _fieldLabelStyle),
        pw.SizedBox(width: 5),
        pw.Expanded(
          child: pw.Container(
            height: 13,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _black, width: 0.5),
              ),
            ),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(value, style: _fieldValueStyle),
            ),
          ),
        ),
      ],
    );
  }

  // ── 8. Footer ─────────────────────────────────────────────────────────────
  //
  // Structure (top → bottom):
  //   1. Thick yellow top bar (full width)
  //   2. Row: [yellow short line] [italic thank-you text] [yellow short line] ... [gear icon bottom-right]
  //   3. Near-black bottom bar with black wave/curve suggestion at bottom-left

  static pw.Widget _buildFooter(pw.MemoryImage footerLogo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Thick yellow top bar
        pw.Container(height: 6, color: _yellow),
        pw.SizedBox(height: 5),

        // Thank-you row + gear icon
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Left yellow line
            pw.Container(width: 50, height: 1.2, color: _yellow),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Center(
                child: pw.Text(
                  "Thank you for choosing Timo's Engineering Service.",
                  style: _footerThankYouStyle,
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
            pw.SizedBox(width: 6),
            // Right yellow line
            pw.Container(width: 50, height: 1.2, color: _yellow),
            pw.SizedBox(width: 8),
            // Gear/lightning logo — bottom-right
            pw.SizedBox(
              width: 30,
              height: 30,
              child: pw.Image(footerLogo, fit: pw.BoxFit.contain),
            ),
          ],
        ),
        pw.SizedBox(height: 4),

        // Near-black bottom bar (with a subtle yellow arc hint at bottom-left
        // achieved by layering a yellow container clipped behind the black bar)
        pw.Stack(
          children: [
            pw.Container(
              height: 16,
              color: _nearBlack,
            ),
            // Yellow wave suggestion: a yellow circle peeking from bottom-left
            pw.Positioned(
              left: -10,
              bottom: 0,
              child: pw.Container(
                width: 60,
                height: 30,
                decoration: const pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: _yellow,
                ),
              ),
            ),
          ],
        ),
      ],
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
