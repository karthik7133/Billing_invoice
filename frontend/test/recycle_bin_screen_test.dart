import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/customer_model.dart';
import 'package:frontend/models/invoice_model.dart';
import 'package:frontend/models/business_model.dart';
import 'package:frontend/providers/business_provider.dart';
import 'package:frontend/providers/customer_provider.dart';
import 'package:frontend/providers/invoice_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/customers/recycle_bin_screen.dart';
import 'package:frontend/widgets/desktop_container.dart';

void main() {
  final customer = CustomerModel(
    id: 'cust_recycle_1',
    name: 'Sri Krishna Traders',
    phone: '9876543210',
    state: 'Andhra Pradesh',
    openingBalance: 0.0,
  );

  final business = BusinessModel(
    id: 'biz_recycle_1',
    businessName: 'JMJ SEA FOODS',
    phone: '9010966188',
    email: 'info@jmjseafoods.com',
    state: 'Andhra Pradesh',
  );

  final deletedInvoice = InvoiceModel(
    id: 'inv_del_1',
    invoiceNumber: 'INV-550',
    customerId: customer.id,
    customerSnapshot: customer,
    businessSnapshot: business,
    invoiceDate: DateTime.now().subtract(const Duration(days: 5)),
    dueDate: DateTime.now(),
    deletedAt: DateTime.now().subtract(const Duration(days: 2)),
    isDeleted: true,
    subtotal: 5000.0,
    taxableAmount: 5000.0,
    grandTotal: 5000.0,
    amountPaid: 5000.0,
    balanceDue: 0.0,
    status: 'PAID',
    paymentType: 'Cash',
    items: [
      InvoiceItemModel(
        productId: 'prod_1',
        name: 'Fish Fillet',
        quantity: 10,
        unit: 'Kg',
        rate: 500,
        grossAmount: 5000,
        taxableAmount: 5000,
        gstRate: 0,
        total: 5000,
      ),
    ],
  );

  testWidgets('RecycleBinScreen renders empty state when no deleted items exist', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    final businessProvider = BusinessProvider();
    final customerProvider = CustomerProvider();
    final invoiceProvider = InvoiceProvider();
    final productProvider = ProductProvider();

    invoiceProvider.setInvoicesForTesting([]);

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
          home: RecycleBinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(RecycleBinScreen), findsOneWidget);
    expect(find.byType(DesktopContainer), findsOneWidget);
    expect(find.text('Recycle Bin is Empty'), findsOneWidget);
    expect(find.text('Return Back'), findsOneWidget);
  });

  testWidgets('RecycleBinScreen renders desktop container, info banner, and well-sized action buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = AuthProvider();
    final businessProvider = BusinessProvider();
    final customerProvider = CustomerProvider();
    final invoiceProvider = InvoiceProvider();
    final productProvider = ProductProvider();

    invoiceProvider.setInvoicesForTesting([deletedInvoice]);

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
          home: RecycleBinScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify screen and desktop container
    expect(find.byType(RecycleBinScreen), findsOneWidget);
    expect(find.byType(DesktopContainer), findsOneWidget);

    // Verify AppBar Empty Bin button
    expect(find.text('Empty Bin'), findsOneWidget);

    // Verify info banner at top
    expect(find.textContaining('1 Sale in Recycle Bin'), findsOneWidget);

    // Verify invoice card contents
    expect(find.text('#INV-550'), findsOneWidget);
    expect(find.text('Sri Krishna Traders'), findsOneWidget);
    expect(find.textContaining('28 days left'), findsOneWidget);

    // Verify nicely styled action buttons
    expect(find.text('Delete Forever'), findsOneWidget);
    expect(find.text('Restore Sale'), findsOneWidget);

    // Tap Delete Forever to open confirmation dialog
    await tester.tap(find.text('Delete Forever'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Permanently?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
