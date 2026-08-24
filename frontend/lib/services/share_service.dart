import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/invoice_model.dart';
import 'pdf_invoice_service.dart';

class ShareService {
  static Future<void> printInvoice(InvoiceModel invoice) async {
    final pdfBytes = await PdfInvoiceService.generateTaxInvoicePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  static Future<void> shareInvoicePdf(InvoiceModel invoice) async {
    final pdfBytes = await PdfInvoiceService.generateTaxInvoicePdf(invoice);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }
}
