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
import 'package:frontend/screens/customers/party_details_screen.dart';
import 'package:frontend/core/utils/currency_formatter.dart';

void main() {
  final customer = CustomerModel(
    id: 'cust_refresh_1',
    name: 'Balaji Fisheries',
    phone: '9848022338',
    state: 'Andhra Pradesh',
    openingBalance: 0.0,
  );

  final business = BusinessModel(
    id: 'biz_refresh_1',
    businessName: 'JMJ SEA FOODS',
    phone: '9010966188',
    email: 'info@jmjseafoods.com',
    state: 'Andhra Pradesh',
  );

  final deletedInvoice = InvoiceModel(
    id: 'inv_restored_1',
    invoiceNumber: 'INV-900',
    customerId: customer.id,
    customerSnapshot: customer,
    businessSnapshot: business,
    invoiceDate: DateTime.now().subtract(const Duration(days: 1)),
    dueDate: DateTime.now(),
    deletedAt: DateTime.now(),
    isDeleted: true,
    subtotal: 7500.0,
    taxableAmount: 7500.0,
    grandTotal: 7500.0,
    amountPaid: 7500.0,
    balanceDue: 0.0,
    status: 'PAID',
    paymentType: 'Cash',
    items: [
      InvoiceItemModel(
        productId: 'prod_1',
        name: 'Tiger Prawns',
        quantity: 15,
        unit: 'Kg',
        rate: 500,
        grossAmount: 7500,
        taxableAmount: 7500,
        gstRate: 0,
        total: 7500,
      ),
    ],
  );

  testWidgets('InvoiceProvider immediately reflects restored invoice in memory with restoredInvoice', (WidgetTester tester) async {
    final invoiceProvider = InvoiceProvider();
    invoiceProvider.setInvoicesForTesting([]);

    expect(invoiceProvider.getInvoicesForCustomer(customer.id).isEmpty, isTrue);

    // Calling restoreInvoice with restoredInvoice immediately adds it to active in-memory list before network
    invoiceProvider.restoreInvoice(deletedInvoice.id, restoredInvoice: deletedInvoice);

    final activeInvoices = invoiceProvider.getInvoicesForCustomer(customer.id);
    expect(activeInvoices.length, equals(1));
    expect(activeInvoices.first.invoiceNumber, equals('INV-900'));
    expect(activeInvoices.first.isDeleted, isFalse);
  });

  testWidgets('PartyDetailsScreen renders refresh button in AppBar and reflects restored invoices', (WidgetTester tester) async {
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
        child: MaterialApp(
          home: PartyDetailsScreen(customer: customer),
        ),
      ),
    );

    await tester.pump();

    // Verify Party Details screen
    expect(find.byType(PartyDetailsScreen), findsOneWidget);

    // Verify Refresh Button exists in AppBar
    expect(find.byTooltip('Refresh Party Data'), findsOneWidget);

    // Initially no transactions
    expect(find.text('#INV-900'), findsNothing);

    // Immediate reflection of restored invoice
    invoiceProvider.restoreInvoice(deletedInvoice.id, restoredInvoice: deletedInvoice);
    await tester.pump();

    // Immediately reflected in Party Details
    expect(find.text('#INV-900'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(7500.0)), findsWidgets);
  });
}
