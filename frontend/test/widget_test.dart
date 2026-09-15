import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/business_provider.dart';
import 'package:frontend/providers/customer_provider.dart';
import 'package:frontend/providers/invoice_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/invoices/create_invoice_screen.dart';
import 'package:frontend/widgets/desktop_container.dart';

void main() {
  testWidgets('GST Billing App sanity smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GstBillingApp());
    expect(find.byType(GstBillingApp), findsOneWidget);
  });

  testWidgets('CreateInvoiceScreen renders on Windows Desktop without errors', (WidgetTester tester) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      final authProvider = AuthProvider();
      final businessProvider = BusinessProvider();
      final customerProvider = CustomerProvider();
      final invoiceProvider = InvoiceProvider();
      final productProvider = ProductProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: businessProvider),
            ChangeNotifierProvider.value(value: customerProvider),
            ChangeNotifierProvider.value(value: invoiceProvider),
            ChangeNotifierProvider.value(value: productProvider),
          ],
          child: const MaterialApp(
            home: CreateInvoiceScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CreateInvoiceScreen), findsOneWidget);
      final bodyFinder = find.byType(SingleChildScrollView);
      debugPrint('Found SingleChildScrollView: ${bodyFinder.evaluate().length}');
      if (bodyFinder.evaluate().isNotEmpty) {
        final renderBox = tester.renderObject<RenderBox>(bodyFinder);
        debugPrint('SingleChildScrollView size: ${renderBox.size}');
        final scrollable = tester.widget<SingleChildScrollView>(bodyFinder);
        debugPrint('SingleChildScrollView child: ${scrollable.child.runtimeType}');
        final columnFinder = find.descendant(of: bodyFinder, matching: find.byType(Column)).first;
        final colBox = tester.renderObject<RenderBox>(columnFinder);
        debugPrint('Column size: ${colBox.size}');
      }
      final desktopContainerFinder = find.byType(DesktopContainer);
      debugPrint('Found DesktopContainer: ${desktopContainerFinder.evaluate().length}');
      if (desktopContainerFinder.evaluate().isNotEmpty) {
        final renderBox = tester.renderObject<RenderBox>(desktopContainerFinder);
        debugPrint('DesktopContainer size: ${renderBox.size}');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}

