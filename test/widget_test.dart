import 'package:flutter_test/flutter_test.dart';
import 'package:timo_enginerring/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TimosInvoiceApp());
    expect(find.byType(TimosInvoiceApp), findsOneWidget);
  });
}
