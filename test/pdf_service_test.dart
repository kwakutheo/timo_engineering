import 'package:flutter_test/flutter_test.dart';
import 'package:timo_enginerring/data/models/invoice.dart';
import 'package:timo_enginerring/data/models/invoice_item.dart';
import 'package:timo_enginerring/features/invoice/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfService.buildPdf generates valid PDF document without errors',
      () async {
    final invoice = Invoice(
      invoiceNumber: 'TI-2026-001',
      clientName: 'Acme Industries Ltd.',
      billTo: 'Acme Accra Branch',
      address: 'Plot 42 Industrial Area, Accra, Ghana',
      phone: '+233 24 123 4567',
      date: DateTime(2026, 11, 6),
      model: 'Perkins 250kVA',
      runningHour: '1,450 hrs',
      nextServiceDate: DateTime(2027, 2, 6),
      jobDescription: 'Quarterly routine generator maintenance and oil change.',
      observations: 'Oil level and coolant level were within normal range.',
      recommendations: 'Inspect the starter battery during the next service.',
      managerName: 'Theophilus Ayebeng',
      transportationAmount: 150.0,
      labourAmount: 500.0,
      otherChargesAmount: 50.0,
      items: [
        InvoiceItem(
          description: '15W40 Engine Oil (20L drum)',
          quantity: 2,
          price: 450.0,
        ),
        InvoiceItem(
          description: 'Primary Fuel Filter',
          quantity: 1,
          price: 120.0,
        ),
        InvoiceItem(
          description: 'Oil Filter Element',
          quantity: 1,
          price: 95.0,
        ),
      ],
    );

    final doc = await PdfService.buildPdf(invoice);
    final bytes = await doc.save();

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
    expect(doc.document.pdfPageList.pages, hasLength(3));
  });

  test('PdfService.buildPdf can generate an invoice-only document', () async {
    final doc = await PdfService.buildPdf(
      Invoice(
        clientName: 'Invoice Only Client',
        address: 'Accra, Ghana',
        phone: '+233 24 123 4567',
        managerName: 'Service Technician',
      ),
      includeServiceReport: false,
    );

    expect(doc.document.pdfPageList.pages, hasLength(1));
  });

  test('PdfService.buildPdf paginates long service reports with branding',
      () async {
    final longReport = List.filled(
      24,
      'Completed generator inspection, cleaned components, verified operating readings, and recorded the technical finding.',
    ).join(' ');

    final doc = await PdfService.buildPdf(
      Invoice(
        invoiceNumber: 'TI-2026-LONG',
        clientName: 'Long Report Client',
        address: 'Accra, Ghana',
        phone: '+233 24 123 4567',
        jobDescription: longReport,
        observations: longReport,
        recommendations: longReport,
        managerName: 'Service Technician',
        items: [
          InvoiceItem(description: 'Service consumable', quantity: 1, price: 1),
        ],
      ),
    );

    expect(doc.document.pdfPageList.pages.length, greaterThan(2));
  });

  test('PdfService.buildPdf handles multi-paragraph service report without orphan headers',
      () async {
    const clipText =
        'Tap on a clip to paste it in the text box. Touch and hold a clip to pin it. '
        'Unpinned clips will be deleted after 1 hour. Welcome to Gboard clipboard, '
        'any text that you copy will be saved here. Tap on a clip to paste it in the text box.';

    final doc = await PdfService.buildPdf(
      Invoice(
        invoiceNumber: 'TI-2026-MULTI',
        clientName: 'Kwaku TK & Associates',
        address: 'Accra, Ghana',
        phone: '+233 24 123 4567',
        jobDescription: '$clipText $clipText',
        observations: '$clipText $clipText',
        recommendations: '$clipText $clipText',
        managerName: 'Kwaku TK',
        items: [
          InvoiceItem(description: 'Engine Oil', quantity: 1, price: 450),
        ],
      ),
    );

    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(doc.document.pdfPageList.pages.length, greaterThanOrEqualTo(2));
  });

  test('Invoice supports custom technicianName and representativeName',
      () async {
    final invoice = Invoice(
      invoiceNumber: 'TI-2026-SIG',
      clientName: 'Kwaku TK & Associates',
      managerName: 'Bright Atiemo Amoani',
      technicianName: 'Kwaku TK',
      representativeName: 'Nana Osei Bonsu',
      items: [
        InvoiceItem(description: 'Oil Filter', quantity: 1, price: 100),
      ],
    );

    expect(invoice.technicianName, equals('Kwaku TK'));
    expect(invoice.representativeName, equals('Nana Osei Bonsu'));

    // Verify serialization round-trip
    final map = invoice.toMap();
    expect(map['technician_name'], equals('Kwaku TK'));
    expect(map['representative_name'], equals('Nana Osei Bonsu'));

    final restored = Invoice.fromMap(map, invoice.items);
    expect(restored.technicianName, equals('Kwaku TK'));
    expect(restored.representativeName, equals('Nana Osei Bonsu'));

    // Verify PDF generation with custom technician and representative
    final doc = await PdfService.buildPdf(invoice);
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(doc.document.pdfPageList.pages, hasLength(3));
  });

  test('PdfService.buildPdf accommodates 20 items on page 1 without overflow',
      () async {
    final invoice = Invoice(
      invoiceNumber: 'TI-2026-20ITEMS',
      clientName: 'Max Items Client',
      address: 'Accra, Ghana',
      phone: '+233 24 123 4567',
      managerName: 'Kwaku TK',
      items: List.generate(
        20,
        (i) => InvoiceItem(
          description: 'Comprehensive generator maintenance service part #$i',
          quantity: 1,
          price: 110.0,
        ),
      ),
    );

    final doc =
        await PdfService.buildPdf(invoice, includeServiceReport: false);
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    expect(doc.document.pdfPageList.pages, hasLength(1));
  });

  test(
      'PdfService.buildPdf places parts and consumables on a dedicated final page',
      () async {
    final invoice = Invoice(
      invoiceNumber: 'TI-2026-PARTS',
      clientName: 'Dedicated Parts Client',
      address: 'Accra, Ghana',
      phone: '+233 24 123 4567',
      managerName: 'Kwaku TK',
      items: [
        InvoiceItem(description: 'Air Filter Element', quantity: 2, price: 150),
        InvoiceItem(description: 'Fuel Filter', quantity: 1, price: 80),
      ],
    );

    final doc = await PdfService.buildPdf(invoice, includeServiceReport: true);
    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
    // Page 1: Invoice, Page 2: Service Report, Page 3: Parts & Consumables Page
    expect(doc.document.pdfPageList.pages, hasLength(3));
  });
}
