import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend/models/customer_model.dart';
import 'package:frontend/models/invoice_model.dart';
import 'package:frontend/models/business_model.dart';
import 'package:frontend/providers/business_provider.dart';
import 'package:frontend/providers/customer_provider.dart';
import 'package:frontend/providers/invoice_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/customers/party_statement_screen.dart';
import 'package:frontend/screens/invoices/invoice_detail_screen.dart';
import 'package:frontend/screens/invoices/create_invoice_screen.dart';

void main() {
  final customer = CustomerModel(
    id: 'cust_split_1',
    name: 'Srinivasa Enterprises',
    phone: '9988776655',
    state: 'Andhra Pradesh',
    openingBalance: 0.0,
  );

  final business = BusinessModel(
    id: 'biz_1',
    businessName: 'JMJ SEA FOODS',
    phone: '9010966188',
    email: 'info@jmjseafoods.com',
    state: 'Andhra Pradesh',
  );

  final now = DateTime.now();
  final payment1Date = DateTime(now.year, now.month, 5);
  final payment2Date = DateTime(now.year, now.month, 12);

  final payment1 = PaymentRecord(
    id: 'pay_1',
    amount: 5000.0,
    type: 'Cash',
    date: payment1Date,
    notes: 'Initial cash payment',
  );

  final payment2 = PaymentRecord(
    id: 'pay_2',
    amount: 5000.0,
    type: 'UPI',
    date: payment2Date,
    notes: 'Second half via UPI',
  );

  final testInvoice = InvoiceModel(
    id: 'inv_split_1',
    invoiceNumber: 'INV-1001',
    customerId: customer.id,
    customerSnapshot: customer,
    businessSnapshot: business,
    invoiceDate: payment1Date,
    dueDate: payment2Date,
    subtotal: 10000.0,
    taxableAmount: 10000.0,
    grandTotal: 10000.0,
    amountPaid: 10000.0,
    balanceDue: 0.0,
    status: 'PAID',
    paymentType: 'Cash',
    payments: [payment1, payment2],
    items: [
      InvoiceItemModel(
        productId: 'prod_1',
        name: 'Tiger Prawns',
        quantity: 10,
        unit: 'Kg',
        rate: 1000,
        grossAmount: 10000,
        taxableAmount: 10000,
        gstRate: 0,
        total: 10000,
      ),
    ],
  );

  testWidgets('PartyStatementScreen displays split payments on their actual distinct dates', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    final businessProvider = BusinessProvider();
    final customerProvider = CustomerProvider();
    final invoiceProvider = InvoiceProvider();
    final productProvider = ProductProvider();

    invoiceProvider.setInvoicesForTesting([testInvoice]);

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
          home: PartyStatementScreen(
            customer: customer,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Party Statement renders
    expect(find.byType(PartyStatementScreen), findsOneWidget);

    // Verify that both payment dates are present
    final date1Str = DateFormat('dd MMM, yy').format(payment1.date);
    final date2Str = DateFormat('dd MMM, yy').format(payment2.date);

    expect(find.text(date1Str), findsWidgets);
    expect(find.text(date2Str), findsWidgets);

    // Verify both Cash and UPI appear as modes
    expect(find.textContaining('Cash'), findsWidgets);
    expect(find.textContaining('UPI'), findsWidgets);
  });

  testWidgets('InvoiceDetailScreen shows payment installments with distinct dates and Edit Sale action', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    final businessProvider = BusinessProvider();
    final customerProvider = CustomerProvider();
    final invoiceProvider = InvoiceProvider();
    final productProvider = ProductProvider();

    invoiceProvider.setInvoicesForTesting([testInvoice]);

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
          home: InvoiceDetailScreen(invoice: testInvoice),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Payment Installments section header is present
    expect(find.text('Payment Installments & Dates'), findsOneWidget);

    // Verify installment count badge
    expect(find.text('2 Payments'), findsOneWidget);

    // Verify installment details and notes
    expect(find.text('Initial cash payment'), findsOneWidget);
    expect(find.text('Second half via UPI'), findsOneWidget);

    // Verify Edit Sale button is available
    expect(find.text('EDIT SALE & ITEMS'), findsOneWidget);

    // Verify Add Payment Installment button is available
    expect(find.text('Add Payment Installment'), findsOneWidget);
  });

  testWidgets('CreateInvoiceScreen in edit mode preloads existing invoice data and displays Edit Sale title', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    final businessProvider = BusinessProvider();
    final customerProvider = CustomerProvider();
    final invoiceProvider = InvoiceProvider();
    final productProvider = ProductProvider();

    invoiceProvider.setInvoicesForTesting([testInvoice]);

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
          home: CreateInvoiceScreen(existingInvoice: testInvoice),
        ),
      ),
    );

    await tester.pump();

    // Verify Edit Sale title with invoice number
    expect(find.text('Edit Sale #${testInvoice.invoiceNumber}'), findsOneWidget);

    // Verify Update Sale button is displayed instead of Save Sale
    expect(find.text('Update Sale'), findsOneWidget);
  });
}
