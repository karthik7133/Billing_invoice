import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_model.dart';
import '../models/customer_model.dart';
import '../models/business_model.dart';
import '../core/utils/currency_formatter.dart';

class PdfInvoiceService {
  // Exact Design Tokens from LaTeX Sales Bill Template
  static final PdfColor brandPurple = PdfColor.fromHex('#8B85D9');
  static final PdfColor textGray = PdfColor.fromHex('#5F5F5F');
  static final PdfColor lineGray = PdfColor.fromHex('#D9D9D9');
  static final PdfColor darkText = PdfColor.fromHex('#1A1A1A');
  static final PdfColor lightPurple = PdfColor.fromHex('#F0EFFF');

  /// Resolves the company logo image from network, base64 data URI, local file, or asset bundle fallback.
  static Future<pw.ImageProvider?> _resolveLogoImage(String? logoUrl) async {
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      final trimmed = logoUrl.trim();
      try {
        // 1. Network image (Cloudinary / HTTPS / HTTP)
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          return await networkImage(trimmed);
        }
        // 2. Base64 or Data URI
        if (trimmed.startsWith('data:image') || trimmed.contains('base64,')) {
          final commaIdx = trimmed.indexOf(',');
          final base64Str = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
          final bytes = base64Decode(base64Str.replaceAll(RegExp(r'\s+'), ''));
          return pw.MemoryImage(bytes);
        }
        // 3. Local file
        final file = File(trimmed);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return pw.MemoryImage(bytes);
        }
      } catch (_) {
        // Fall through to asset fallback on error
      }
    }

    // Default fallback: crab_logo.png from assets
    try {
      return await imageFromAssetBundle('assets/images/crab_logo.png');
    } catch (_) {
      try {
        final byteData = await rootBundle.load('assets/images/crab_logo.png');
        return pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }

  static Future<Uint8List> generateTaxInvoicePdf(InvoiceModel invoice) async {
    final pdf = pw.Document();

    // High quality font with full unicode and ₹ glyph support
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    final business = invoice.businessSnapshot;
    final customer = invoice.customerSnapshot;

    // Use company logo from businessSnapshot if available, else fall back to crab_logo.png
    final logoImage = await _resolveLogoImage(business.logo);

    // Quantity calculations
    final totalQty = invoice.items.fold<double>(0, (sum, it) => sum + it.quantity);
    final isWholeTotalQty = totalQty.truncateToDouble() == totalQty;
    final totalQtyString = isWholeTotalQty ? totalQty.toStringAsFixed(0) : totalQty.toStringAsFixed(2);

    // Excess / Over Money logic
    final grandTotal = invoice.grandTotal;
    final received = invoice.amountPaid;
    final hasExcess = received > grandTotal || invoice.excessAmount > 0;
    final excessAmount = invoice.overMoneyAmount;
    final displayBalance = hasExcess ? 0.0 : (grandTotal > received ? (grandTotal - received) : 0.0);

    final dateString = DateFormat('dd-MM-yyyy').format(invoice.invoiceDate);

    // Amount in words
    String amountInWords = invoice.amountInWords.trim();
    if (amountInWords.isEmpty) {
      amountInWords = CurrencyFormatter.format(grandTotal);
    }
    if (!amountInWords.toLowerCase().endsWith('only') && !amountInWords.toLowerCase().endsWith('rupees')) {
      amountInWords = '$amountInWords Rupees only';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: const PdfPageFormat(
          8.5 * PdfPageFormat.inch,
          11.0 * PdfPageFormat.inch,
          marginLeft: 1.9 * PdfPageFormat.cm,
          marginRight: 1.9 * PdfPageFormat.cm,
          marginTop: 1.6 * PdfPageFormat.cm,
          marginBottom: 1.6 * PdfPageFormat.cm,
        ),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),
        build: (context) => [
          // ─── 1. HEADER: Company Block (Left 68%) + Crab Logo (Right 28%) ───
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Left: Company Block
              pw.Expanded(
                flex: 7,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      business.businessName.isNotEmpty ? business.businessName.toUpperCase() : 'JMJ SEA FOODS',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 20,
                        color: darkText,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (business.phone.isNotEmpty)
                      pw.Text(
                        'Phone no.: ${business.phone}',
                        style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                      ),
                    if (business.email.isNotEmpty)
                      pw.Text(
                        'Email: ${business.email}',
                        style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                      ),
                    if (business.gstin.isNotEmpty)
                      pw.Text(
                        'GSTIN: ${business.gstin}',
                        style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                      ),
                  ],
                ),
              ),

              // Right: Crab Logo (Top Right)
              pw.Container(
                width: 65,
                height: 65,
                alignment: pw.Alignment.center,
                child: logoImage != null
                    ? pw.Image(logoImage, width: 65, height: 65, fit: pw.BoxFit.contain)
                    : pw.Container(
                        width: 50,
                        height: 50,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: brandPurple, width: 1.5),
                        ),
                        child: pw.Text(
                          'CRAB',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: brandPurple,
                          ),
                        ),
                      ),
              ),
            ],
          ),

          pw.SizedBox(height: 6),
          // Bolder line on top of Sales Bill matching sales bill color (brandPurple)
          pw.Divider(color: brandPurple, thickness: 1.8),
          pw.SizedBox(height: 3),

          // ─── 2. TITLE: SALES BILL (without bottom line) ───
          pw.Center(
            child: pw.Text(
              'SALES BILL',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 22,
                color: brandPurple,
                letterSpacing: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // ─── 3. BILL TO (Left 55%) / INVOICE DETAILS (Right 40%) ───
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Bill To
              pw.Expanded(
                flex: 55,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Bill To',
                      style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      customer.name.isNotEmpty ? customer.name : 'SVSF/TN',
                      style: pw.TextStyle(font: fontBold, fontSize: 11, color: darkText),
                    ),
                    if (customer.phone.isNotEmpty)
                      pw.Text(
                        'Phone: ${customer.phone}',
                        style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                      ),
                    if (customer.billingAddress.isNotEmpty)
                      pw.Text(
                        customer.billingAddress,
                        style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                      ),
                  ],
                ),
              ),

              // Invoice Details
              pw.Expanded(
                flex: 40,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Invoice Details',
                      style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Invoice No.: ${invoice.invoiceNumber}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 10, color: darkText),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Date: $dateString',
                      style: pw.TextStyle(font: fontRegular, fontSize: 10, color: darkText),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'ORIGIN: ${invoice.origin.isNotEmpty ? invoice.origin.toUpperCase() : "AP"}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 10, color: darkText),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // ─── 4. ITEMS TABLE ───
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(3.8),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FixedColumnWidth(72),
              5: const pw.FixedColumnWidth(88),
            },
            children: [
              // Header Row: brandPurple background, white bold text
              pw.TableRow(
                decoration: pw.BoxDecoration(color: brandPurple),
                children: [
                  _buildTableHeader('#', align: pw.TextAlign.center),
                  _buildTableHeader('Item Name', align: pw.TextAlign.left),
                  _buildTableHeader('Quantity', align: pw.TextAlign.center),
                  _buildTableHeader('Unit', align: pw.TextAlign.center),
                  _buildTableHeader('Price/ Unit', align: pw.TextAlign.right),
                  _buildTableHeader('Amount', align: pw.TextAlign.right),
                ],
              ),

              // Data Rows with BOLDER item names
              ...invoice.items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                final isWholeQty = item.quantity.truncateToDouble() == item.quantity;
                final qtyStr = isWholeQty ? item.quantity.toStringAsFixed(0) : item.quantity.toStringAsFixed(2);
                final unitStr = item.unit.isNotEmpty ? item.unit : '--';

                return pw.TableRow(
                  children: [
                    _buildTableCell('$idx', align: pw.TextAlign.center, color: darkText),
                    _buildTableCell(
                      item.name,
                      align: pw.TextAlign.left,
                      color: darkText,
                      isBold: true,
                      fontBold: fontBold,
                      fontSize: 10.2,
                    ),
                    _buildTableCell(qtyStr, align: pw.TextAlign.center, color: darkText),
                    _buildTableCell(unitStr, align: pw.TextAlign.center, color: darkText),
                    _buildTableCell('₹ ${CurrencyFormatter.format(item.rate, showSymbol: false)}', align: pw.TextAlign.right, color: darkText),
                    _buildTableCell('₹ ${CurrencyFormatter.format(item.total, showSymbol: false)}', align: pw.TextAlign.right, color: darkText),
                  ],
                );
              }),
            ],
          ),

          // Total Row in Items Table: thin dark rule above, bold values
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: darkText, width: 0.8),
                bottom: pw.BorderSide(color: lineGray, width: 0.5),
              ),
            ),
            child: pw.Row(
              children: [
                pw.SizedBox(width: 24),
                pw.Expanded(
                  flex: 38,
                  child: pw.Text(
                    'Total',
                    style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                  ),
                ),
                pw.Container(
                  width: 60,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    totalQtyString,
                    style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                  ),
                ),
                pw.SizedBox(width: 40),
                pw.SizedBox(width: 72),
                pw.Container(
                  width: 88,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '₹ ${CurrencyFormatter.format(grandTotal, showSymbol: false)}',
                    style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 18),

          // ─── 5. DESCRIPTION (Left 55%) / TOTALS SUMMARY BOX (Right 40%) ───
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Description
              pw.Expanded(
                flex: 55,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Description',
                      style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      invoice.description.isNotEmpty
                          ? invoice.description
                          : (invoice.notes.isNotEmpty ? invoice.notes : 'Thank you for your business!'),
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9.5,
                        lineSpacing: 2.0,
                        color: darkText,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(width: 20),

              // Totals Summary Box
              pw.Expanded(
                flex: 40,
                child: pw.Column(
                  children: [
                    // Sub Total
                    _buildSummaryRow(
                      'Sub Total',
                      '₹ ${CurrencyFormatter.format(invoice.subtotal > 0 ? invoice.subtotal : grandTotal, showSymbol: false)}',
                      fontRegular: fontRegular,
                      fontBold: fontBold,
                    ),

                    // Purple Bar Total Row
                    pw.Container(
                      color: brandPurple,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      margin: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total',
                            style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.white),
                          ),
                          pw.Text(
                            '₹ ${CurrencyFormatter.format(grandTotal, showSymbol: false)}',
                            style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.white),
                          ),
                        ],
                      ),
                    ),

                    // Received
                    _buildSummaryRow(
                      'Received',
                      '₹ ${CurrencyFormatter.format(received, showSymbol: false)}',
                      fontRegular: fontRegular,
                      fontBold: fontBold,
                    ),

                    // Balance
                    _buildSummaryRow(
                      'Balance',
                      '₹ ${CurrencyFormatter.format(displayBalance, showSymbol: false)}',
                      fontRegular: fontRegular,
                      fontBold: fontBold,
                    ),

                    // Advance / Excess Received Row
                    if (hasExcess) ...[
                      pw.Container(
                        color: lightPurple,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        margin: const pw.EdgeInsets.only(top: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Advance / Excess Received',
                              style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: darkText),
                            ),
                            pw.Text(
                              '₹ ${CurrencyFormatter.format(excessAmount, showSymbol: false)}',
                              style: pw.TextStyle(font: fontBold, fontSize: 10, color: brandPurple),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ─── 6. AMOUNT IN WORDS ───
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Invoice Amount In Words',
                style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                amountInWords,
                style: pw.TextStyle(font: fontRegular, fontSize: 10, color: darkText),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    bool isBold = false,
    pw.Font? fontBold,
    double? fontSize,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: isBold ? fontBold : null,
          fontSize: fontSize ?? 9.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromHex('#1A1A1A'),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    required pw.Font fontRegular,
    required pw.Font fontBold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#1A1A1A')),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#1A1A1A')),
          ),
        ],
      ),
    );
  }

  // ─── Party Statement PDF (Matching SVSF TN Reference Layout Pixel-to-Pixel) ─

  static Future<Uint8List> generatePartyStatementPdf({
    required CustomerModel customer,
    required List<InvoiceModel> invoices,
    required DateTime fromDate,
    required DateTime toDate,
    BusinessModel? business,
    bool showItemDetails = true,
    bool showDescription = false,
    bool showPaymentStatus = false,
    bool showPaymentInfo = true,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    final b = business ??
        (invoices.isNotEmpty
            ? invoices.first.businessSnapshot
            : BusinessModel(id: '', businessName: 'JMJ SEA FOODS', phone: '9010966188', email: 'donijoel12345@gmail.com'));

    // Logo
    final logoImage = await _resolveLogoImage(b.logo);

    final dfmt = DateFormat('dd/MM/yyyy');

    final fromDay = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final toDay = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

    // Calculate opening balance before fromDate
    double runningBalance = customer.openingBalance;
    for (final inv in invoices) {
      if (inv.invoiceDate.isBefore(fromDay)) {
        runningBalance += (inv.grandTotal - inv.amountPaid);
      }
    }
    final initialOpening = runningBalance;

    final filtered = invoices.where((inv) {
      final d = inv.invoiceDate;
      return !d.isBefore(fromDay) && !d.isAfter(toDay);
    }).toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    // Master Table Column Widths (Exact Proportion to A4 Usable Width)
    const masterColWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(56), // Date
      1: pw.FixedColumnWidth(48), // Txn Type
      2: pw.FixedColumnWidth(54), // Invoice/ Bill No.
      3: pw.FixedColumnWidth(78), // Total Amount
      4: pw.FixedColumnWidth(82), // Received/ Paid Amount
      5: pw.FixedColumnWidth(68), // Txn Balance
      6: pw.FixedColumnWidth(74), // Receivable Balance
      7: pw.FixedColumnWidth(63), // Payable Balance
    };

    String formatBillNo(String invoiceNumber) {
      final trimmed = invoiceNumber.trim();
      if (trimmed.isEmpty) return '-';
      if (RegExp(r'^\d+$').hasMatch(trimmed)) {
        return 'No$trimmed';
      }
      return trimmed;
    }

    String formatQty(double qty) {
      if (qty.truncateToDouble() == qty) {
        return qty.toInt().toString();
      }
      return qty.toStringAsFixed(2);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),
        footer: (ctx) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${ctx.pageNumber}',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 9,
                color: PdfColor.fromHex('#9CA3AF'),
              ),
            ),
          );
        },
        build: (ctx) {
          final contentWidgets = <pw.Widget>[];

          // ─── 1. TOP HEADER: Logo (Left) + Business Info (Right) ───
          contentWidgets.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Left: Company Logo
                if (logoImage != null)
                  pw.Container(
                    width: 75,
                    height: 50,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Image(logoImage, width: 75, height: 50, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Container(width: 75, height: 50),

                // Right: Business Name & Contact Info
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      b.businessName.isNotEmpty ? b.businessName.toUpperCase() : 'JMJ SEA FOODS',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        if (b.phone.isNotEmpty)
                          pw.Text(
                            'Phone no.: ${b.phone}  ',
                            style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black),
                          ),
                        if (b.email.isNotEmpty)
                          pw.Text(
                            'Email: ${b.email}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );

          contentWidgets.add(pw.SizedBox(height: 6));
          contentWidgets.add(pw.Divider(color: PdfColors.black, thickness: 1.0));
          contentWidgets.add(pw.SizedBox(height: 14));

          // ─── 2. STATEMENT TITLE & PARTY INFO ───
          contentWidgets.add(
            pw.Center(
              child: pw.Text(
                'Party Statement',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 20,
                  color: PdfColors.black,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          );

          contentWidgets.add(pw.SizedBox(height: 16));

          contentWidgets.add(
            pw.Text(
              'Party name: ${customer.name.isNotEmpty ? customer.name : "Customer"}',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: PdfColors.black,
              ),
            ),
          );

          contentWidgets.add(pw.SizedBox(height: 6));

          contentWidgets.add(
            pw.Text(
              'Duration: From ${dfmt.format(fromDate)} to ${dfmt.format(toDate)}',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: PdfColors.black,
              ),
            ),
          );

          contentWidgets.add(pw.SizedBox(height: 14));

          // ─── 3. MASTER TABLE HEADER ───
          contentWidgets.add(
            pw.Table(
              columnWidths: masterColWidths,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE0E0E0),
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  children: [
                    _masterHeaderCell('Date', fontBold),
                    _masterHeaderCell('Txn Type', fontBold),
                    _masterHeaderCell('Invoice/ Bill\nNo.', fontBold, align: pw.TextAlign.center),
                    _masterHeaderCell('Total Amount', fontBold, align: pw.TextAlign.right),
                    _masterHeaderCell('Received/ Paid\nAmount', fontBold, align: pw.TextAlign.right),
                    _masterHeaderCell('Txn Balance', fontBold, align: pw.TextAlign.right),
                    _masterHeaderCell('Receivable\nBalance', fontBold, align: pw.TextAlign.right),
                    _masterHeaderCell('Payable\nBalance', fontBold, align: pw.TextAlign.right),
                  ],
                ),
              ],
            ),
          );

          // ─── 4. OPENING BALANCE (If non-zero) ───
          if (initialOpening != 0) {
            final recBal = initialOpening > 0 ? initialOpening : 0.0;
            final payBal = initialOpening < 0 ? initialOpening.abs() : 0.0;

            contentWidgets.add(
              pw.Table(
                columnWidths: masterColWidths,
                children: [
                  pw.TableRow(
                    children: [
                      _txnCell(dfmt.format(fromDate), fontBold),
                      _txnCell('Opening Balance', fontBold),
                      _txnCell('-', fontBold, align: pw.TextAlign.center),
                      _txnCell('-', fontBold, align: pw.TextAlign.right),
                      _txnCell('-', fontBold, align: pw.TextAlign.right),
                      _txnCell('₹ ${CurrencyFormatter.format(initialOpening.abs(), showSymbol: false)}', fontBold, align: pw.TextAlign.right),
                      _txnCell(recBal > 0 ? '₹ ${CurrencyFormatter.format(recBal, showSymbol: false)}' : '₹ 0.00', fontBold, align: pw.TextAlign.right),
                      _txnCell(payBal > 0 ? '₹ ${CurrencyFormatter.format(payBal, showSymbol: false)}' : '', fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),
            );
            contentWidgets.add(pw.Divider(color: PdfColor.fromHex('#E0E0E0'), thickness: 0.6));
          }

          // ─── 5. TRANSACTIONS LIST ───
          for (final inv in filtered) {
            final txnTotal = inv.grandTotal;
            final txnReceived = inv.amountPaid;
            final txnBalance = txnTotal - txnReceived;

            runningBalance += txnBalance;

            final receivableBalance = runningBalance > 0 ? runningBalance : 0.0;
            final payableBalance = runningBalance < 0 ? runningBalance.abs() : 0.0;

            final totalItemQty = inv.items.fold<double>(0.0, (s, it) => s + it.quantity);

            contentWidgets.add(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 4),

                  // A. Main Transaction Row
                  pw.Table(
                    columnWidths: masterColWidths,
                    children: [
                      pw.TableRow(
                        children: [
                          _txnCell(dfmt.format(inv.invoiceDate), fontBold),
                          _txnCell('Sale', fontBold),
                          _txnCell(formatBillNo(inv.invoiceNumber), fontBold, align: pw.TextAlign.center),
                          _txnCell('₹ ${CurrencyFormatter.format(txnTotal, showSymbol: false)}', fontBold, align: pw.TextAlign.right),
                          _txnCell('₹ ${CurrencyFormatter.format(txnReceived, showSymbol: false)}', fontBold, align: pw.TextAlign.right),
                          _txnCell('₹ ${CurrencyFormatter.format(txnBalance, showSymbol: false)}', fontBold, align: pw.TextAlign.right),
                          _txnCell('₹ ${CurrencyFormatter.format(receivableBalance, showSymbol: false)}', fontBold, align: pw.TextAlign.right),
                          _txnCell(payableBalance > 0 ? '₹ ${CurrencyFormatter.format(payableBalance, showSymbol: false)}' : '', fontBold, align: pw.TextAlign.right),
                        ],
                      ),
                    ],
                  ),

                  // B. Nested Items Table (Indented matching reference PDF)
                  if (showItemDetails && inv.items.isNotEmpty) ...[
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 65, right: 0, top: 4, bottom: 2),
                      child: pw.Table(
                        columnWidths: const {
                          0: pw.FixedColumnWidth(22), // #
                          1: pw.FlexColumnWidth(2.5), // Item Name
                          2: pw.FixedColumnWidth(55), // Quantity
                          3: pw.FixedColumnWidth(38), // Unit
                          4: pw.FixedColumnWidth(75), // Price/ Unit
                          5: pw.FixedColumnWidth(85), // Amount
                        },
                        children: [
                          // Item table header
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFE0E0E0),
                              border: pw.Border(
                                top: pw.BorderSide(color: PdfColors.black, width: 0.6),
                                bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
                              ),
                            ),
                            children: [
                              _itemHeaderCell('#', fontBold, align: pw.TextAlign.center),
                              _itemHeaderCell('Item Name', fontBold),
                              _itemHeaderCell('Quantity', fontBold, align: pw.TextAlign.right),
                              _itemHeaderCell('Unit', fontBold, align: pw.TextAlign.center),
                              _itemHeaderCell('Price/ Unit', fontBold, align: pw.TextAlign.right),
                              _itemHeaderCell('Amount', fontBold, align: pw.TextAlign.right),
                            ],
                          ),

                          // Item data rows
                          ...inv.items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final it = entry.value;
                            return pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.4),
                                ),
                              ),
                              children: [
                                _itemCell('${idx + 1}', fontRegular, align: pw.TextAlign.center),
                                _itemCell(it.name.toUpperCase(), fontRegular),
                                _itemCell(formatQty(it.quantity), fontRegular, align: pw.TextAlign.right),
                                _itemCell(it.unit.isNotEmpty ? it.unit : '-', fontRegular, align: pw.TextAlign.center),
                                _itemCell('₹ ${CurrencyFormatter.format(it.rate, showSymbol: false)}', fontRegular, align: pw.TextAlign.right),
                                _itemCell('₹ ${CurrencyFormatter.format(it.total, showSymbol: false)}', fontRegular, align: pw.TextAlign.right),
                              ],
                            );
                          }),

                          // Item total row
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                                bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                              ),
                            ),
                            children: [
                              _itemCell('', fontRegular),
                              _itemCell('Total', fontBold, isBold: true),
                              _itemCell(formatQty(totalItemQty), fontBold, align: pw.TextAlign.right, isBold: true),
                              _itemCell('', fontRegular),
                              _itemCell('', fontRegular),
                              _itemCell('₹ ${CurrencyFormatter.format(inv.grandTotal, showSymbol: false)}', fontBold, align: pw.TextAlign.right, isBold: true),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Sub Total row below item table
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 0, top: 3, bottom: 3),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('Sub Total: ', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black)),
                            pw.Text('₹ ${CurrencyFormatter.format(inv.grandTotal, showSymbol: false)}', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // C. Payment Type
                  if (showPaymentInfo)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'Payment Type: ', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColors.black)),
                            pw.TextSpan(text: inv.paymentType.isNotEmpty ? inv.paymentType : 'Cash', style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: PdfColors.black)),
                          ],
                        ),
                      ),
                    ),

                  // D. Note / Description if requested
                  if (showDescription && inv.description.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text('Note: ${inv.description}', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColor.fromHex('#4B5563'))),
                    ),

                  pw.SizedBox(height: 2),
                  pw.Divider(color: PdfColors.black, thickness: 0.8),
                ],
              ),
            );
          }

          // ─── 6. GRAND TOTAL SUMMARY AT END OF STATEMENT ───
          contentWidgets.add(pw.SizedBox(height: 20));
          contentWidgets.add(
            pw.Text(
              runningBalance > 0
                  ? 'Total Receivable balance: ₹ ${CurrencyFormatter.format(runningBalance, showSymbol: false)}'
                  : (runningBalance < 0
                      ? 'Total Payable balance: ₹ ${CurrencyFormatter.format(runningBalance.abs(), showSymbol: false)}'
                      : 'Total Balance: ₹ 0.00 (Settled)'),
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: PdfColors.black,
              ),
            ),
          );

          return contentWidgets;
        },
      ),
    );

    return pdf.save();
  }

  // ─── General Ledger & Daybook PDF ──────────────────────────────────────────

  static Future<Uint8List> generateGeneralLedgerPdf({
    required List<InvoiceModel> invoices,
    required DateTime fromDate,
    required DateTime toDate,
    BusinessModel? business,
    CustomerModel? specificCustomer,
    bool showItemDetails = true,
    bool showPaymentInfo = true,
    bool showBalance = true,
    bool showPaymentStatus = true,
    bool showGrandTotals = true,
    String reportTitle = 'GENERAL LEDGER & DAYBOOK',
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    final b = business ??
        (invoices.isNotEmpty
            ? invoices.first.businessSnapshot
            : BusinessModel(id: '', businessName: 'JMJ SEA FOODS', phone: '9010966188', email: 'donijoel12345@gmail.com'));

    final logoImage = await _resolveLogoImage(b.logo);
    final dfmt = DateFormat('dd/MM/yyyy');

    final fromDay = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final toDay = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

    final filtered = invoices.where((inv) {
      final d = inv.invoiceDate;
      return !d.isBefore(fromDay) && !d.isAfter(toDay);
    }).toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    String formatBillNo(String invoiceNumber) {
      final trimmed = invoiceNumber.trim();
      if (trimmed.isEmpty) return '-';
      if (RegExp(r'^\d+$').hasMatch(trimmed)) {
        return 'No$trimmed';
      }
      return trimmed;
    }

    String formatQty(double qty) {
      if (qty.truncateToDouble() == qty) {
        return qty.toInt().toString();
      }
      return qty.toStringAsFixed(2);
    }

    // Dynamic Column Widths based on options
    final Map<int, pw.TableColumnWidth> colWidths = {};
    int colIdx = 0;

    colWidths[colIdx++] = const pw.FixedColumnWidth(54); // Date
    colWidths[colIdx++] = const pw.FixedColumnWidth(52); // Voucher #
    colWidths[colIdx++] = const pw.FlexColumnWidth(2.2); // Party Name

    if (showItemDetails) {
      colWidths[colIdx++] = const pw.FlexColumnWidth(2.5); // Items (Merged with Qty + Unit)
    }

    colWidths[colIdx++] = const pw.FixedColumnWidth(68); // Bill Total (₹)

    if (showPaymentInfo) {
      colWidths[colIdx++] = const pw.FixedColumnWidth(64); // Received (₹)
    }

    if (showBalance) {
      colWidths[colIdx++] = const pw.FixedColumnWidth(64); // Balance (₹)
    }

    if (showPaymentStatus) {
      colWidths[colIdx++] = const pw.FixedColumnWidth(48); // Status
    }

    double totalBilled = 0.0;
    double totalPaid = 0.0;
    double totalDue = 0.0;

    for (final inv in filtered) {
      totalBilled += inv.grandTotal;
      totalPaid += inv.amountPaid;
      totalDue += inv.balanceDue;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          italic: fontItalic,
        ),
        footer: (ctx) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${ctx.pageNumber}',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 9,
                color: PdfColor.fromHex('#9CA3AF'),
              ),
            ),
          );
        },
        build: (ctx) {
          final contentWidgets = <pw.Widget>[];

          // ─── 1. TOP HEADER: Logo (Left) + Business Info (Right) ───────────
          contentWidgets.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Left: Company Logo
                if (logoImage != null)
                  pw.Container(
                    width: 75,
                    height: 50,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Image(logoImage, width: 75, height: 50, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Container(width: 75, height: 50),

                // Right: Business Name & Contact Info
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      b.businessName.isNotEmpty ? b.businessName.toUpperCase() : 'JMJ SEA FOODS',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        if (b.phone.isNotEmpty)
                          pw.Text(
                            'Phone no.: ${b.phone}  ',
                            style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black),
                          ),
                        if (b.email.isNotEmpty)
                          pw.Text(
                            'Email: ${b.email}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black),
                          ),
                      ],
                    ),
                    if (b.gstin.isNotEmpty)
                      pw.Text(
                        'GSTIN: ${b.gstin}',
                        style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black),
                      ),
                  ],
                ),
              ],
            ),
          );

          contentWidgets.add(pw.SizedBox(height: 6));
          contentWidgets.add(pw.Divider(color: PdfColors.black, thickness: 1.0));
          contentWidgets.add(pw.SizedBox(height: 12));

          // ─── 2. STATEMENT TITLE & METADATA ────────────────────────────────
          contentWidgets.add(
            pw.Center(
              child: pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 18,
                  color: PdfColors.black,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          );

          contentWidgets.add(pw.SizedBox(height: 10));

          if (specificCustomer != null) {
            contentWidgets.add(
              pw.Text(
                'Party name: ${specificCustomer.name}',
                style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
              ),
            );
            contentWidgets.add(pw.SizedBox(height: 4));
          }

          contentWidgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Duration: From ${dfmt.format(fromDate)} to ${dfmt.format(toDate)}',
                  style: pw.TextStyle(font: fontBold, fontSize: 11.5, color: PdfColors.black),
                ),
                pw.Text(
                  'Total Entries: ${filtered.length}',
                  style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColor.fromHex('#4B5563')),
                ),
              ],
            ),
          );

          contentWidgets.add(pw.SizedBox(height: 10));

          // ─── 3. TABLE HEADER ──────────────────────────────────────────────
          final List<pw.Widget> headerCells = [
            _masterHeaderCell('Date', fontBold),
            _masterHeaderCell('Bill No.', fontBold, align: pw.TextAlign.center),
            _masterHeaderCell('Party Name', fontBold),
          ];

          if (showItemDetails) {
            headerCells.add(_masterHeaderCell('Items (Qty)', fontBold));
          }

          headerCells.add(_masterHeaderCell('Bill Amt', fontBold, align: pw.TextAlign.right));

          if (showPaymentInfo) {
            headerCells.add(_masterHeaderCell('Received', fontBold, align: pw.TextAlign.right));
          }

          if (showBalance) {
            headerCells.add(_masterHeaderCell('Balance', fontBold, align: pw.TextAlign.right));
          }

          if (showPaymentStatus) {
            headerCells.add(_masterHeaderCell('Status', fontBold, align: pw.TextAlign.center));
          }

          contentWidgets.add(
            pw.Table(
              columnWidths: colWidths,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE0E0E0),
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.black, width: 0.8),
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                  children: headerCells,
                ),
              ],
            ),
          );

          // ─── 4. TABLE DATA ROWS ───────────────────────────────────────────
          for (final inv in filtered) {
            final isPaid = inv.status == 'PAID';
            final isPartial = inv.status == 'PARTIALLY_PAID' || (inv.amountPaid > 0 && inv.balanceDue > 0);
            final statusStr = isPaid ? 'PAID' : (isPartial ? 'PARTIAL' : 'DUE');

            // Merge item names and quantities with units: e.g. "Crab (5 kg), Prawns (2 kg)"
            final itemSummary = inv.items.isNotEmpty
                ? inv.items
                    .map((it) => '${it.name} (${formatQty(it.quantity)}${it.unit.isNotEmpty ? " ${it.unit}" : ""})')
                    .join(', ')
                : '-';

            final List<pw.Widget> rowCells = [
              _txnCell(dfmt.format(inv.invoiceDate), fontRegular),
              _txnCell(formatBillNo(inv.invoiceNumber), fontBold, align: pw.TextAlign.center),
              _txnCell(inv.customerSnapshot.name.isNotEmpty ? inv.customerSnapshot.name : 'Customer', fontBold),
            ];

            if (showItemDetails) {
              rowCells.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
                  child: pw.Text(
                    itemSummary,
                    style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.black),
                    maxLines: 2,
                  ),
                ),
              );
            }

            rowCells.add(
              _txnCell('₹ ${CurrencyFormatter.format(inv.grandTotal, showSymbol: false)}', fontBold, align: pw.TextAlign.right),
            );

            if (showPaymentInfo) {
              rowCells.add(
                _txnCell('₹ ${CurrencyFormatter.format(inv.amountPaid, showSymbol: false)}', fontRegular, align: pw.TextAlign.right),
              );
            }

            if (showBalance) {
              rowCells.add(
                _txnCell('₹ ${CurrencyFormatter.format(inv.balanceDue, showSymbol: false)}', fontBold, align: pw.TextAlign.right),
              );
            }

            if (showPaymentStatus) {
              rowCells.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
                  child: pw.Text(
                    statusStr,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8,
                      color: isPaid
                          ? PdfColor.fromHex('#15803D')
                          : (isPartial ? PdfColor.fromHex('#B45309') : PdfColor.fromHex('#B91C1C')),
                    ),
                  ),
                ),
              );
            }

            contentWidgets.add(
              pw.Table(
                columnWidths: colWidths,
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
                      ),
                    ),
                    children: rowCells,
                  ),
                ],
              ),
            );
          }

          // ─── 5. GRAND TOTALS SUMMARY ──────────────────────────────────────
          if (showGrandTotals && filtered.isNotEmpty) {
            contentWidgets.add(pw.SizedBox(height: 14));
            contentWidgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF3F4F6),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFD1D5DB), width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTALS (${filtered.length} Bills)',
                      style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black),
                    ),
                    pw.Text(
                      'Billed: ₹ ${CurrencyFormatter.format(totalBilled, showSymbol: false)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black),
                    ),
                    if (showPaymentInfo)
                      pw.Text(
                        'Received: ₹ ${CurrencyFormatter.format(totalPaid, showSymbol: false)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColor.fromHex('#15803D')),
                      ),
                    if (showBalance)
                      pw.Text(
                        'Pending Due: ₹ ${CurrencyFormatter.format(totalDue, showSymbol: false)}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: totalDue > 0 ? PdfColor.fromHex('#B91C1C') : PdfColor.fromHex('#15803D'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          return contentWidgets;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _masterHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.black,
          fontSize: 9,
          font: font,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _txnCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _itemHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.black,
          fontSize: 8.5,
          font: font,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _itemCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }
}



