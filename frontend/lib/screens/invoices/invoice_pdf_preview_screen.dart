import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../models/invoice_model.dart';
import '../../services/pdf_invoice_service.dart';

class InvoicePdfPreviewScreen extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoicePdfPreviewScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tax Invoice - ${invoice.invoiceNumber}'),
      ),
      body: PdfPreview(
        build: (format) => PdfInvoiceService.generateTaxInvoicePdf(invoice),
        initialPageFormat: PdfPageFormat.a4,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Invoice_${invoice.invoiceNumber}.pdf',
        previewPageMargin: const EdgeInsets.all(12),
      ),
    );
  }
}
