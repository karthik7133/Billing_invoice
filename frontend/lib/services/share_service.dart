import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/platform_helper.dart';
import '../models/invoice_model.dart';
import '../widgets/pdf_progress_dialog.dart';
import 'pdf_invoice_service.dart';

class ShareService {
  /// Print invoice with a loading dialog so the UI doesn't freeze silently.
  static Future<void> printInvoice(InvoiceModel invoice, {BuildContext? context}) async {
    if (context != null && context.mounted) {
      PdfProgressDialog.show(context, message: 'Preparing Invoice for Print...');
    }
    try {
      final pdfBytes = await PdfInvoiceService.generateTaxInvoicePdf(invoice);
      if (context != null) PdfProgressDialog.hide();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Invoice_${invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (context != null) PdfProgressDialog.hide();
      rethrow;
    }
  }

  /// Share invoice PDF with a loading dialog so the UI doesn't freeze silently.
  static Future<void> shareInvoicePdf(InvoiceModel invoice, {BuildContext? context}) async {
    if (context != null && context.mounted) {
      PdfProgressDialog.show(context, message: 'Generating Invoice PDF...');
    }
    try {
      final pdfBytes = await PdfInvoiceService.generateTaxInvoicePdf(invoice);
      if (context != null) PdfProgressDialog.hide();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Invoice_${invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (context != null) PdfProgressDialog.hide();
      rethrow;
    }
  }

  static Future<void> sharePdf(Uint8List bytes, {required String filename}) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  /// Opens or saves the XLS file.
  /// On Windows: saves to Downloads and opens with the default app via cmd /c start.
  /// On Android/iOS: uses share sheet (open_filex removed to avoid Windows crash).
  static Future<bool> openXlsFile(
    Uint8List bytes, {
    required String filename,
  }) async {
    final sanitizedName = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';
    try {
      if (PlatformHelper.isWindows) {
        return await _openFileOnWindows(bytes, sanitizedName);
      }
      // Android / iOS — fall through to share sheet
      await shareXlsFile(bytes, filename: sanitizedName);
      return true;
    } catch (_) {
      await shareXlsFile(bytes, filename: sanitizedName);
      return false;
    }
  }

  /// Windows: save to Downloads folder then open with default application.
  static Future<bool> _openFileOnWindows(Uint8List bytes, String filename) async {
    try {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
      final downloadsPath = '$home\\Downloads';
      final dir = Directory(downloadsPath).existsSync()
          ? Directory(downloadsPath)
          : await getTemporaryDirectory();

      final file = File('${dir.path}\\$filename');
      await file.writeAsBytes(bytes, flush: true);

      // Open with Windows default app (Excel, LibreOffice, etc.)
      await Process.run('cmd', ['/c', 'start', '', file.path]);
      return true;
    } catch (e) {
      debugPrint('[ShareService] Windows open error: $e');
      return false;
    }
  }

  static Future<void> shareXlsFile(
    Uint8List bytes, {
    required String filename,
    String? subject,
  }) async {
    final sanitizedName = filename.endsWith('.xlsx') ? filename : '$filename.xlsx';

    // Windows: no native share sheet — save to Downloads folder instead
    if (PlatformHelper.isWindows) {
      await _openFileOnWindows(bytes, sanitizedName);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
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
