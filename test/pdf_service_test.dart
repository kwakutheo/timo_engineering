import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_enginerring/data/models/invoice.dart';
import 'package:timo_enginerring/data/models/invoice_item.dart';
import 'package:timo_enginerring/features/invoice/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PdfService.buildPdf generates valid PDF document without errors', () async {
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

    // Also write out to disk so we can inspect it if needed
    final testPdfFile = File('test_output_invoice.pdf');
    await testPdfFile.writeAsBytes(bytes);
    expect(testPdfFile.existsSync(), isTrue);
  });
}
