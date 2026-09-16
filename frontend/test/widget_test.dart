import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('GST Billing App sanity smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GstBillingApp());
    expect(find.byType(GstBillingApp), findsOneWidget);
  });
}
