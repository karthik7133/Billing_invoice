import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_model.dart';
import '../core/utils/currency_formatter.dart';

class PdfInvoiceService {
  static Future<Uint8List> generateTaxInvoicePdf(InvoiceModel invoice) async {
    final pdf = pw.Document();

    // Fetch Google font for clean rendering
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();
    final fontSemiBold = await PdfGoogleFonts.interSemiBold();

    final business = invoice.businessSnapshot;
    final customer = invoice.customerSnapshot;

    // Load business logo if available (network or fallback)
    pw.ImageProvider? logoImage;
    if (business.logo.isNotEmpty && business.logo.startsWith('http')) {
      try {
        logoImage = await networkImage(business.logo);
      } catch (e) {
        logoImage = null;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
          fontFallback: [fontRegular, fontSemiBold],
        ),
        build: (context) => [
          // 1. Header with Tax Invoice Title
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    font: fontBold,
                    color: PdfColors.white,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                pw.Text(
                  invoice.isInterState ? 'INTER-STATE (IGST)' : 'INTRA-STATE (CGST + SGST)',
                  style: pw.TextStyle(
                    font: fontRegular,
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // 2. Business & Invoice Header Info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business Details
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        height: 44,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 6),
                    ],
                    pw.Text(
                      business.businessName.isNotEmpty ? business.businessName : 'ABC ELECTRONICS',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900),
                    ),
                    if (business.address.isNotEmpty)
                      pw.Text('${business.address}, ${business.city}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('State: ${business.state} (${business.stateCode})', style: const pw.TextStyle(fontSize: 9)),
                    if (business.gstin.isNotEmpty)
                      pw.Text('GSTIN: ${business.gstin}', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
                    if (business.pan.isNotEmpty)
                      pw.Text('PAN: ${business.pan}', style: const pw.TextStyle(fontSize: 9)),
                    if (business.phone.isNotEmpty)
                      pw.Text('Phone: ${business.phone}', style: const pw.TextStyle(fontSize: 9)),
                    if (business.email.isNotEmpty)
                      pw.Text('Email: ${business.email}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),

              pw.SizedBox(width: 14),

              // Invoice Details Card
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Invoice No:', invoice.invoiceNumber, fontBold: fontBold),
                      _buildInfoRow('Invoice Date:', CurrencyFormatter.formatDate(invoice.invoiceDate)),
                      _buildInfoRow('Due Date:', CurrencyFormatter.formatDate(invoice.dueDate)),
                      _buildInfoRow('Place of Supply:', customer.state.isNotEmpty ? customer.state : business.state),
                      _buildInfoRow('Status:', invoice.status, color: invoice.status == 'PAID' ? PdfColors.green700 : PdfColors.red700),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          pw.SizedBox(height: 6),

          // 3. Customer Info (Bill To / Ship To)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO / BUYER DETAILS', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text(customer.name, style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      if (customer.billingAddress.isNotEmpty)
                        pw.Text(customer.billingAddress, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('State: ${customer.state} (${customer.stateCode})', style: const pw.TextStyle(fontSize: 9)),
                      if (customer.gstin.isNotEmpty)
                        pw.Text('GSTIN: ${customer.gstin}', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                      if (customer.phone.isNotEmpty)
                        pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SHIP TO', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text(customer.name, style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      pw.Text(
                        customer.shippingAddress.isNotEmpty ? customer.shippingAddress : customer.billingAddress,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text('Type: ${customer.customerType.replaceAll('_', ' ')}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // 4. Itemized Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),  // #
              1: const pw.FlexColumnWidth(3.5),  // Item
              2: const pw.FlexColumnWidth(1.2),  // HSN
              3: const pw.FlexColumnWidth(1.0),  // Qty
              4: const pw.FlexColumnWidth(1.3),  // Rate
              5: const pw.FlexColumnWidth(1.4),  // Taxable
              6: const pw.FlexColumnWidth(1.0),  // Tax %
              7: const pw.FlexColumnWidth(1.5),  // Amount
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableHeader('#'),
                  _buildTableHeader('Item Description'),
                  _buildTableHeader('HSN/SAC'),
                  _buildTableHeader('Qty'),
                  _buildTableHeader('Rate (₹)'),
                  _buildTableHeader('Taxable (₹)'),
                  _buildTableHeader('GST %'),
                  _buildTableHeader('Total (₹)'),
                ],
              ),
              // Items
              ...invoice.items.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;
                return pw.TableRow(
                  children: [
                    _buildTableCell('$idx', align: pw.TextAlign.center),
                    _buildTableCell(item.name, font: fontBold),
                    _buildTableCell(item.hsnSac.isNotEmpty ? item.hsnSac : '-', align: pw.TextAlign.center),
                    _buildTableCell('${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.unit}', align: pw.TextAlign.center),
                    _buildTableCell(item.rate.toStringAsFixed(2), align: pw.TextAlign.right),
                    _buildTableCell(item.taxableAmount.toStringAsFixed(2), align: pw.TextAlign.right),
                    _buildTableCell('${item.gstRate.toStringAsFixed(0)}%', align: pw.TextAlign.center),
                    _buildTableCell(item.total.toStringAsFixed(2), align: pw.TextAlign.right, font: fontBold),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 12),

          // 5. Tax Breakdown & Financial Totals
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left: Amount in Words & Bank Details
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Amount in Words:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                          pw.Text(
                            invoice.amountInWords.isNotEmpty ? invoice.amountInWords : 'Rupees Only',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, fontStyle: pw.FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),

                    // Description & Notes
                    if (invoice.description.isNotEmpty || invoice.notes.isNotEmpty) ...[
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Notes / Description:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                            pw.Text(
                              invoice.description.isNotEmpty ? invoice.description : invoice.notes,
                              style: pw.TextStyle(font: fontRegular, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 6),
                    ],

                    // Payment Method Badge
                    if (invoice.paymentType.isNotEmpty) ...[
                      pw.Row(
                        children: [
                          pw.Text('Payment Type: ', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                          pw.Text(invoice.paymentType, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.blue900)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                    ],

                    // Bank Details
                    if (business.bankDetails.accountNumber.isNotEmpty || business.bankDetails.upiId.isNotEmpty) ...[
                      pw.Text('Bank & Payment Details:', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColors.blue900)),
                      pw.SizedBox(height: 2),
                      if (business.bankDetails.bankName.isNotEmpty)
                        pw.Text('Bank: ${business.bankDetails.bankName}', style: const pw.TextStyle(fontSize: 8)),
                      if (business.bankDetails.accountNumber.isNotEmpty)
                        pw.Text('A/C No: ${business.bankDetails.accountNumber}', style: const pw.TextStyle(fontSize: 8)),
                      if (business.bankDetails.ifscCode.isNotEmpty)
                        pw.Text('IFSC: ${business.bankDetails.ifscCode}', style: const pw.TextStyle(fontSize: 8)),
                      if (business.bankDetails.upiId.isNotEmpty)
                        pw.Text('UPI ID: ${business.bankDetails.upiId}', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(width: 14),

              // Right: Financial Summary Box
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      _buildSummaryRow('Subtotal:', '₹ ${invoice.subtotal.toStringAsFixed(2)}'),
                      if (invoice.totalDiscount > 0)
                        _buildSummaryRow('Discount:', '- ₹ ${invoice.totalDiscount.toStringAsFixed(2)}', color: PdfColors.red700),
                      _buildSummaryRow('Taxable Amount:', '₹ ${invoice.taxableAmount.toStringAsFixed(2)}'),
                      if (!invoice.isInterState) ...[
                        _buildSummaryRow('CGST:', '₹ ${invoice.cgst.toStringAsFixed(2)}'),
                        _buildSummaryRow('SGST:', '₹ ${invoice.sgst.toStringAsFixed(2)}'),
                      ] else ...[
                        _buildSummaryRow('IGST:', '₹ ${invoice.igst.toStringAsFixed(2)}'),
                      ],
                      if (invoice.otherCharges > 0)
                        _buildSummaryRow('Other Charges:', '₹ ${invoice.otherCharges.toStringAsFixed(2)}'),
                      if (invoice.roundOff != 0)
                        _buildSummaryRow('Round Off:', '₹ ${invoice.roundOff.toStringAsFixed(2)}'),
                      pw.Divider(color: PdfColors.grey400, thickness: 0.6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Grand Total:', style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue900)),
                          pw.Text('₹ ${invoice.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.blue900)),
                        ],
                      ),
                      if (invoice.amountPaid > 0) ...[
                        pw.SizedBox(height: 4),
                        _buildSummaryRow('Received / Paid:', '₹ ${invoice.amountPaid.toStringAsFixed(2)}', color: PdfColors.green700, fontBold: fontBold),
                        _buildSummaryRow('Balance Due:', '₹ ${invoice.balanceDue.toStringAsFixed(2)}', fontBold: fontBold, color: invoice.balanceDue > 0 ? PdfColors.red700 : PdfColors.green700),
                      ],
                      if (invoice.hasOverMoney) ...[
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pw.BorderRadius.circular(2),
                            border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                          ),
                          child: _buildSummaryRow(
                            'Extra / Over Money:',
                            '₹ ${invoice.overMoneyAmount.toStringAsFixed(2)}',
                            fontBold: fontBold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // 6. Terms and Signature
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Terms & Conditions:', style: pw.TextStyle(font: fontBold, fontSize: 8.5)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      invoice.termsAndConditions.isNotEmpty
                          ? invoice.termsAndConditions
                          : '1. Goods once sold will not be taken back.\n2. Subject to local jurisdiction.',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'For ${business.businessName.isNotEmpty ? business.businessName : "ABC Electronics"}',
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 34),
                    pw.Container(
                      width: 120,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 0.8)),
                      ),
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(
                          'Authorized Signatory',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    pw.Font? font,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 8.5),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value, {
    pw.Font? fontBold,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    pw.Font? fontBold,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 8.5,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
