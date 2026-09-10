import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
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

  static Future<void> sharePdf(Uint8List bytes, {required String filename}) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  /// Directly opens the XLS file in Microsoft Excel, WPS Office, Google Sheets, or other supported apps.
  /// If no default app is available or opening fails, falls back to the system share sheet.
  static Future<bool> openXlsFile(
    Uint8List bytes, {
    required String filename,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';
      final file = File('${tempDir.path}/$sanitizedName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (result.type != ResultType.done) {
        // Fallback to share sheet so user can still choose an app or save file
        await shareXlsFile(bytes, filename: sanitizedName);
        return false;
      }
      return true;
    } catch (_) {
      final sanitizedName = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';
      await shareXlsFile(bytes, filename: sanitizedName);
      return false;
    }
  }

  static Future<void> shareXlsFile(
    Uint8List bytes, {
    required String filename,
    String? subject,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';
      final file = File('${tempDir.path}/$sanitizedName');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: sanitizedName,
            ),
          ],
          subject: subject,
        ),
      );
    } catch (_) {
      final sanitizedName = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              name: sanitizedName,
            ),
          ],
          subject: subject,
        ),
      );
    }
  }

  static Future<void> shareText({required String text, String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
      ),
    );
  }
}
