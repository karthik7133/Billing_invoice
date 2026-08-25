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

  static Future<Uint8List> generateTaxInvoicePdf(InvoiceModel invoice) async {
    final pdf = pw.Document();

    // High quality font with full unicode and ₹ glyph support
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    final business = invoice.businessSnapshot;
    final customer = invoice.customerSnapshot;

    // Load crab_logo.png from assets, with network/memory fallback
    pw.ImageProvider? logoImage;
    try {
      logoImage = await imageFromAssetBundle('assets/images/crab_logo.png');
    } catch (_) {
      try {
        final byteData = await rootBundle.load('assets/images/crab_logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {
        if (business.logo.isNotEmpty && business.logo.startsWith('http')) {
          try {
            logoImage = await networkImage(business.logo);
          } catch (_) {
            logoImage = null;
          }
        }
      }
    }

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

  // ─── Party Statement PDF ──────────────────────────────────────────────────

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
            : BusinessModel(id: '', businessName: 'JMJ SEA FOODS'));

    // Load crab_logo.png from assets, with network/memory fallback (exact match with Tax Invoice)
    pw.ImageProvider? logoImage;
    try {
      logoImage = await imageFromAssetBundle('assets/images/crab_logo.png');
    } catch (_) {
      try {
        final byteData = await rootBundle.load('assets/images/crab_logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (_) {
        if (b.logo.isNotEmpty && b.logo.startsWith('http')) {
          try {
            logoImage = await networkImage(b.logo);
          } catch (_) {
            logoImage = null;
          }
        }
      }
    }

    final dfmt = DateFormat('dd-MM-yyyy');
    final dfmtShort = DateFormat('dd MMM yy');

    double balance = 0.0;
    double totalPurchases = 0.0;
    double totalPaid = 0.0;

    // Filter invoices within the date range and sort chronologically
    final filtered = invoices.where((inv) {
      final d = inv.invoiceDate;
      final fromDay = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final toDay = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
      return !d.isBefore(fromDay) && !d.isAfter(toDay);
    }).toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

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
        build: (ctx) {
          return [
            // ─── 1. CONSTANT HEADER: Company Block + Crab Logo ───
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
                        b.businessName.isNotEmpty ? b.businessName.toUpperCase() : 'JMJ SEA FOODS',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 20,
                          color: darkText,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (b.phone.isNotEmpty)
                        pw.Text(
                          'Phone no.: ${b.phone}',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                        ),
                      if (b.email.isNotEmpty)
                        pw.Text(
                          'Email: ${b.email}',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                        ),
                      if (b.gstin.isNotEmpty)
                        pw.Text(
                          'GSTIN: ${b.gstin}',
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
            pw.Divider(color: brandPurple, thickness: 1.8),
            pw.SizedBox(height: 3),

            // ─── 2. TITLE: PARTY STATEMENT ───
            pw.Center(
              child: pw.Text(
                'PARTY STATEMENT',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 20,
                  color: brandPurple,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            pw.SizedBox(height: 12),

            // ─── 3. BILL TO (Left 55%) / STATEMENT PERIOD (Right 40%) ───
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Bill To / Customer
                pw.Expanded(
                  flex: 55,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Party Details',
                        style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        customer.name.isNotEmpty ? customer.name : 'Customer',
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
                      if (customer.gstin.isNotEmpty)
                        pw.Text(
                          'GSTIN: ${customer.gstin}',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9.5, color: textGray),
                        ),
                    ],
                  ),
                ),

                // Statement Period
                pw.Expanded(
                  flex: 40,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Statement Period',
                        style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: darkText),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'From: ${dfmt.format(fromDate)}',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10, color: darkText),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'To: ${dfmt.format(toDate)}',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10, color: darkText),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Total Txns: ${filtered.length}',
                        style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: brandPurple),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 14),

            // ─── 4. TRANSACTIONS LEDGER TABLE ───
            pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(65),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(2.0),
                if (showPaymentStatus) 3: const pw.FixedColumnWidth(60),
                if (showPaymentStatus) 4: const pw.FixedColumnWidth(80),
                if (showPaymentStatus) 5: const pw.FixedColumnWidth(80),
                if (!showPaymentStatus) 3: const pw.FixedColumnWidth(80),
                if (!showPaymentStatus) 4: const pw.FixedColumnWidth(80),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: brandPurple),
                  children: [
                    _stmtHeader('Date', fontBold),
                    _stmtHeader('Type / Particulars', fontBold),
                    _stmtHeader('Ref No.', fontBold),
                    if (showPaymentStatus) _stmtHeader('Status', fontBold, align: pw.TextAlign.center),
                    _stmtHeader('Amount (₹)', fontBold, align: pw.TextAlign.right),
                    _stmtHeader('Balance (₹)', fontBold, align: pw.TextAlign.right),
                  ],
                ),

                // Opening Balance Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.white),
                  children: [
                    _stmtCell(dfmtShort.format(fromDate), fontRegular),
                    _stmtCell('Opening Balance', fontBold, isBold: true, font: fontBold),
                    _stmtCell('-', fontRegular),
                    if (showPaymentStatus) _stmtCell('-', fontRegular, align: pw.TextAlign.center),
                    _stmtCell('0.00', fontRegular, align: pw.TextAlign.right),
                    _stmtCell('0.00', fontBold, align: pw.TextAlign.right, color: PdfColor.fromHex('#16A34A')),
                  ],
                ),

                // Transactions
                ...filtered.expand((inv) {
                  totalPurchases += inv.grandTotal;
                  balance += inv.grandTotal;

                  final rowsList = <pw.TableRow>[];

                  // Purchase row
                  final statusText = inv.isPaid ? 'PAID' : (inv.balanceDue < inv.grandTotal ? 'PARTIAL' : 'UNPAID');
                  final statusColor = inv.isPaid
                      ? PdfColor.fromHex('#16A34A')
                      : (inv.balanceDue < inv.grandTotal ? PdfColor.fromHex('#2563EB') : PdfColor.fromHex('#DC2626'));

                  // Build details subtext if item details / description requested
                  String detailsSubtext = '';
                  if (showItemDetails && inv.items.isNotEmpty) {
                    detailsSubtext += inv.items.map((it) => '${it.name} (${it.quantity}${it.unit.isNotEmpty ? it.unit : ''} @ ₹${CurrencyFormatter.format(it.rate, showSymbol: false)})').join(', ');
                  }
                  if (showDescription && inv.description.isNotEmpty) {
                    if (detailsSubtext.isNotEmpty) detailsSubtext += '\n';
                    detailsSubtext += 'Note: ${inv.description}';
                  }

                  rowsList.add(
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.white),
                      children: [
                        _stmtCell(dfmtShort.format(inv.invoiceDate), fontRegular),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Purchase', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: darkText)),
                              if (detailsSubtext.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  detailsSubtext,
                                  style: pw.TextStyle(font: fontRegular, fontSize: 8, color: textGray),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _stmtCell('#${inv.invoiceNumber}', fontRegular),
                        if (showPaymentStatus)
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                            child: pw.Center(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: pw.BoxDecoration(
                                  color: lightPurple,
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                                ),
                                child: pw.Text(
                                  statusText,
                                  style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: statusColor),
                                ),
                              ),
                            ),
                          ),
                        _stmtCell(CurrencyFormatter.format(inv.grandTotal, showSymbol: false), fontRegular, align: pw.TextAlign.right),
                        _stmtCell(CurrencyFormatter.format(balance, showSymbol: false), fontBold, align: pw.TextAlign.right, color: balance > 0 ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#16A34A')),
                      ],
                    ),
                  );

                  // Payment row (if any payment recorded on invoice)
                  if (inv.amountPaid > 0) {
                    totalPaid += inv.amountPaid;
                    balance -= inv.amountPaid;
                    final paymentInfoStr = showPaymentInfo && inv.paymentType.isNotEmpty ? ' (${inv.paymentType})' : '';

                    rowsList.add(
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                        children: [
                          _stmtCell(dfmtShort.format(inv.invoiceDate), fontRegular),
                          _stmtCell('Payment Received$paymentInfoStr', fontRegular, color: PdfColor.fromHex('#16A34A')),
                          _stmtCell('#${inv.invoiceNumber}', fontRegular),
                          if (showPaymentStatus) _stmtCell('-', fontRegular, align: pw.TextAlign.center),
                          _stmtCell('-${CurrencyFormatter.format(inv.amountPaid, showSymbol: false)}', fontRegular, align: pw.TextAlign.right, color: PdfColor.fromHex('#16A34A')),
                          _stmtCell(CurrencyFormatter.format(balance, showSymbol: false), fontBold, align: pw.TextAlign.right, color: balance > 0 ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#16A34A')),
                        ],
                      ),
                    );
                  }

                  return rowsList;
                }),
              ],
            ),

            pw.SizedBox(height: 14),

            // ─── 5. SUMMARY BOX (Left: Bank Details if showPaymentInfo, Right: Totals) ───
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Left: Bank & Payment Info if enabled
                if (showPaymentInfo && (b.bankDetails.bankName.isNotEmpty || b.bankDetails.upiId.isNotEmpty))
                  pw.Expanded(
                    flex: 55,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: lightPurple,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: brandPurple.flatten(), width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Payment & Bank Information',
                            style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: darkText),
                          ),
                          pw.SizedBox(height: 4),
                          if (b.bankDetails.bankName.isNotEmpty)
                            pw.Text('Bank: ${b.bankDetails.bankName}', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: darkText)),
                          if (b.bankDetails.accountNumber.isNotEmpty)
                            pw.Text('A/C No: ${b.bankDetails.accountNumber}', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: darkText)),
                          if (b.bankDetails.ifscCode.isNotEmpty)
                            pw.Text('IFSC: ${b.bankDetails.ifscCode}', style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: darkText)),
                          if (b.bankDetails.upiId.isNotEmpty)
                            pw.Text('UPI ID: ${b.bankDetails.upiId}', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: brandPurple)),
                        ],
                      ),
                    ),
                  )
                else
                  pw.Spacer(flex: 55),

                pw.SizedBox(width: 16),

                // Right: Totals Breakdown Box
                pw.Expanded(
                  flex: 42,
                  child: pw.Column(
                    children: [
                      _buildSummaryRow(
                        'Total Purchases',
                        '₹ ${CurrencyFormatter.format(totalPurchases, showSymbol: false)}',
                        fontRegular: fontRegular,
                        fontBold: fontBold,
                      ),
                      _buildSummaryRow(
                        'Total Paid / Received',
                        '₹ ${CurrencyFormatter.format(totalPaid, showSymbol: false)}',
                        fontRegular: fontRegular,
                        fontBold: fontBold,
                      ),
                      pw.Container(
                        color: brandPurple,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        margin: const pw.EdgeInsets.only(top: 4),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Closing Balance',
                              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.white),
                            ),
                            pw.Text(
                              '₹ ${CurrencyFormatter.format(balance, showSymbol: false)}',
                              style: pw.TextStyle(font: fontBold, fontSize: 10.5, color: PdfColors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _stmtHeader(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9.5,
          font: font,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _stmtCell(
    String text,
    pw.Font fontRegular, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    bool isBold = false,
    pw.Font? font,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: isBold ? font : fontRegular,
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromHex('#1A1A1A'),
        ),
      ),
    );
  }
}


