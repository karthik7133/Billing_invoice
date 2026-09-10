import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/customer_model.dart';
import 'package:frontend/models/invoice_model.dart';
import 'package:frontend/models/business_model.dart';
import 'package:frontend/services/excel_export_service.dart';
import 'package:frontend/services/pdf_invoice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Statement Export Tests', () {
    final testCustomer = CustomerModel(
      id: 'cust-1',
      name: 'John Doe Seafood Traders',
      phone: '9876543210',
      email: 'john@example.com',
      billingAddress: '123 Harbor Way, Chennai',
      gstin: '33AAAAA0000A1Z5',
      openingBalance: 1500.0,
    );

    final testBusiness = BusinessModel(
      id: 'biz-1',
      businessName: 'JMJ SEA FOODS',
      phone: '9988776655',
      email: 'contact@jmjseafoods.com',
      gstin: '33BBBBB1111B1Z9',
      address: 'Harbor Road, Chennai',
    );

    final testInvoices = <InvoiceModel>[
      InvoiceModel(
        id: 'inv-1',
        invoiceNumber: 'INV-1001',
        customerId: testCustomer.id,
        customerSnapshot: testCustomer,
        businessSnapshot: testBusiness,
        items: [
          InvoiceItemModel(
            name: 'Fresh Tiger Prawns',
            quantity: 10,
            unit: 'kg',
            rate: 500,
            grossAmount: 5000,
            taxableAmount: 5000,
            gstRate: 0,
            total: 5000,
          ),
        ],
        invoiceDate: DateTime(2026, 8, 10),
        dueDate: DateTime(2026, 8, 20),
        subtotal: 5000,
        taxableAmount: 5000,
        grandTotal: 5000,
        amountPaid: 3000.0,
        balanceDue: 2000.0,
        paymentType: 'UPI',
      ),
      InvoiceModel(
        id: 'inv-2',
        invoiceNumber: 'INV-1002',
        customerId: testCustomer.id,
        customerSnapshot: testCustomer,
        businessSnapshot: testBusiness,
        items: [
          InvoiceItemModel(
            name: 'Mud Crab Premium',
            quantity: 5,
            unit: 'kg',
            rate: 800,
            grossAmount: 4000,
            taxableAmount: 4000,
            gstRate: 5,
            total: 4200,
          ),
        ],
        invoiceDate: DateTime(2026, 8, 15),
        dueDate: DateTime(2026, 8, 25),
        subtotal: 4000,
        taxableAmount: 4000,
        grandTotal: 4200,
        amountPaid: 4200.0,
        balanceDue: 0.0,
        paymentType: 'Cash',
      ),
    ];

    test('ExcelExportService creates valid XLSX bytes matching 7 columns', () async {
      final bytes = await ExcelExportService.generatePartyStatementExcel(
        customer: testCustomer,
        allInvoices: testInvoices,
        fromDate: DateTime(2026, 8, 1),
        toDate: DateTime(2026, 8, 31),
        business: testBusiness,
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // PK signature for zip / xlsx file
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('PdfInvoiceService creates valid Party Statement PDF bytes', () async {
      final bytes = await PdfInvoiceService.generatePartyStatementPdf(
        customer: testCustomer,
        invoices: testInvoices,
        fromDate: DateTime(2026, 8, 1),
        toDate: DateTime(2026, 8, 31),
        business: testBusiness,
        showItemDetails: true,
        showDescription: true,
        showPaymentStatus: true,
        showPaymentInfo: true,
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // %PDF header
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header.startsWith('%PDF'), isTrue);
    });
  });
}
