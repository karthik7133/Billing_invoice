import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../models/business_model.dart';

class ExcelExportService {
  /// Generate a professional, beautifully styled, editable Excel (.xlsx) file
  static Future<Uint8List> generateCustomXlsx({
    required List<InvoiceModel> invoices,
    DateTime? fromDate,
    DateTime? toDate,
    BusinessModel? business,
    CustomerModel? specificCustomer,
    bool includeCompanyHeader = true,
    bool includeCustomerDetails = true,
    bool includeTransactionType = true,
    bool includeItemizedBreakdown = false,
    bool includeTaxDetails = false,
    bool includePaymentDetails = true,
    bool includeOverAmounts = true,
    bool includeBalances = true,
    bool includeGrandTotals = true,
    String reportTitle = 'GENERAL LEDGER & DAYBOOK',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[defaultSheet];

    final dfmt = DateFormat('dd/MM/yyyy');
    final bName = business?.businessName.isNotEmpty == true
        ? business!.businessName
        : 'JMJ SEA FOODS';

    int currentRow = 0;

    // Helper to write a row with individual cell values & styles
    void writeRow(List<CellValue> values, List<CellStyle> styles) {
      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow),
        );
        cell.value = values[col];
        if (col < styles.length) {
          cell.cellStyle = styles[col];
        }
      }
      currentRow++;
    }

    // Common border definitions
    final thinBorder = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#E2E8F0'),
    );
    final headerTopBorder = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#0F172A'),
    );
    final headerBottomBorder = Border(
      borderStyle: BorderStyle.Medium,
      borderColorHex: ExcelColor.fromHexString('#0F172A'),
    );
    final totalTopBorder = Border(
      borderStyle: BorderStyle.Medium,
      borderColorHex: ExcelColor.fromHexString('#94A3B8'),
    );
    final totalBottomBorder = Border(
      borderStyle: BorderStyle.Double,
      borderColorHex: ExcelColor.fromHexString('#475569'),
    );

    // ─── 1. Company & Header Metadata ──────────────────────────────────────────
    if (includeCompanyHeader) {
      final companyStyle = CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
      final titleStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: ExcelColor.fromHexString('#2563EB'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
      final metaStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#475569'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );
      final metaBoldStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      // Business Name
      writeRow([TextCellValue(bName)], [companyStyle]);

      // Report Title
      writeRow([TextCellValue(reportTitle.toUpperCase())], [titleStyle]);

      // Business Contact Info
      if (business != null && (business.gstin.isNotEmpty || business.phone.isNotEmpty || business.address.isNotEmpty)) {
        final List<CellValue> bizMeta = [];
        final List<CellStyle> bizStyles = [];
        if (business.gstin.isNotEmpty) {
          bizMeta.add(TextCellValue('GSTIN: ${business.gstin}'));
          bizStyles.add(metaBoldStyle);
        }
        if (business.phone.isNotEmpty) {
          bizMeta.add(TextCellValue('Phone: ${business.phone}'));
          bizStyles.add(metaStyle);
        }
        if (business.address.isNotEmpty) {
          bizMeta.add(TextCellValue('Address: ${business.address}'));
          bizStyles.add(metaStyle);
        }
        if (bizMeta.isNotEmpty) writeRow(bizMeta, bizStyles);
      }

      // Party Info (if single customer statement)
      if (specificCustomer != null) {
        writeRow(
          [
            TextCellValue('Party Name: ${specificCustomer.name}'),
            TextCellValue('Phone: ${specificCustomer.phone.isNotEmpty ? specificCustomer.phone : "-"}'),
            TextCellValue('GSTIN: ${specificCustomer.gstin.isNotEmpty ? specificCustomer.gstin : "-"}'),
          ],
          [metaBoldStyle, metaStyle, metaStyle],
        );
      }

      // Period & Generation Date
      final periodText = (fromDate != null && toDate != null)
          ? 'Period: ${dfmt.format(fromDate)} to ${dfmt.format(toDate)}'
          : 'Period: All Registered Transactions';

      writeRow(
        [
          TextCellValue(periodText),
          TextCellValue('Generated: ${dfmt.format(DateTime.now())}'),
          TextCellValue('Total Records: ${invoices.length}'),
        ],
        [metaBoldStyle, metaStyle, metaStyle],
      );

      // Blank spacing row
      currentRow++;
    }

    // ─── 2. Build Column Headers ───────────────────────────────────────────────
    final List<CellValue> headerValues = [];
    final List<CellStyle> headerStyles = [];

    CellStyle makeHeaderStyle(HorizontalAlign align) {
      return CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#1E293B'),
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        topBorder: headerTopBorder,
        bottomBorder: headerBottomBorder,
      );
    }

    // 1. Sl No
    headerValues.add(TextCellValue('Sl No'));
    headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));

    // 2. Date
    headerValues.add(TextCellValue('Date'));
    headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));

    // 3. Voucher #
    headerValues.add(TextCellValue('Voucher / Bill #'));
    headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));

    if (includeCustomerDetails) {
      headerValues.add(TextCellValue('Party Name'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Left));

      headerValues.add(TextCellValue('Phone / Contact'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));

      headerValues.add(TextCellValue('GSTIN'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));
    }

    if (includeTransactionType) {
      headerValues.add(TextCellValue('Transaction Type'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));

      headerValues.add(TextCellValue('Payment Mode'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));
    }

    if (includeItemizedBreakdown) {
      headerValues.add(TextCellValue('Item / Product Name'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Left));

      headerValues.add(TextCellValue('Qty'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));

      headerValues.add(TextCellValue('Unit'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));

      headerValues.add(TextCellValue('Rate (₹)'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));

      headerValues.add(TextCellValue('Item Total (₹)'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));
    }

    // Optional single Tax column if explicitly checked
    if (includeTaxDetails) {
      headerValues.add(TextCellValue('Tax (₹)'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));
    }

    // Core Financial Columns
    headerValues.add(TextCellValue('Bill / Debit (₹)'));
    headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));

    if (includePaymentDetails) {
      headerValues.add(TextCellValue('Received / Credit (₹)'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));
    }

    if (includeOverAmounts) {
      headerValues.add(TextCellValue('Over-Payment (₹)'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));
    }

    if (includeBalances) {
      headerValues.add(TextCellValue('Balance Due (₹)'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Right));

      headerValues.add(TextCellValue('Status'));
      headerStyles.add(makeHeaderStyle(HorizontalAlign.Center));
    }

    headerValues.add(TextCellValue('Remarks / Notes'));
    headerStyles.add(makeHeaderStyle(HorizontalAlign.Left));

    writeRow(headerValues, headerStyles);

    // ─── 3. Data Rows ──────────────────────────────────────────────────────────
    final sorted = List<InvoiceModel>.from(invoices)
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    double totalBilled = 0.0;
    double totalPaid = 0.0;
    double totalOver = 0.0;
    double totalDue = 0.0;
    double totalTaxAmt = 0.0;

    int slNo = 1;

    for (int rowIdx = 0; rowIdx < sorted.length; rowIdx++) {
      final inv = sorted[rowIdx];
      final isEven = (rowIdx % 2 == 0);
      final bgHex = isEven ? '#FFFFFF' : '#F8FAFC';

      final custName = inv.customerSnapshot.name.isNotEmpty
          ? inv.customerSnapshot.name
          : 'Customer';
      final phone = inv.customerSnapshot.phone.isNotEmpty
          ? inv.customerSnapshot.phone
          : '-';
      final gstin = inv.customerSnapshot.gstin.isNotEmpty
          ? inv.customerSnapshot.gstin
          : '-';
      final excess = inv.overMoneyAmount > 0 ? inv.overMoneyAmount : 0.0;

      totalBilled += inv.grandTotal;
      totalPaid += inv.amountPaid;
      totalOver += excess;
      totalDue += inv.balanceDue;
      totalTaxAmt += inv.totalTax;

      // Base Styles for this data row
      final textStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#1E293B'),
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: thinBorder,
      );

      final centerStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#334155'),
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: thinBorder,
      );

      final numStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: thinBorder,
      );

      final paidNumStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(inv.amountPaid > 0 ? '#15803D' : '#64748B'),
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: thinBorder,
      );

      final dueNumStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(inv.balanceDue > 0 ? '#B91C1C' : '#64748B'),
        backgroundColorHex: ExcelColor.fromHexString(bgHex),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: thinBorder,
      );

      // Clean status pill style
      final isPaid = inv.status == 'PAID';
      final isPartial = inv.status == 'PARTIALLY_PAID' || (inv.amountPaid > 0 && inv.balanceDue > 0);
      final statusStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString(isPaid ? '#15803D' : (isPartial ? '#B45309' : '#B91C1C')),
        backgroundColorHex: ExcelColor.fromHexString(isPaid ? '#DCFCE7' : (isPartial ? '#FEF3C7' : '#FEE2E2')),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: thinBorder,
      );

      if (includeItemizedBreakdown && inv.items.isNotEmpty) {
        // Multi-line breakdown for this invoice
        for (int i = 0; i < inv.items.length; i++) {
          final it = inv.items[i];
          final List<CellValue> rowVals = [
            IntCellValue(slNo),
            TextCellValue(dfmt.format(inv.invoiceDate)),
            TextCellValue('#${inv.invoiceNumber}'),
          ];
          final List<CellStyle> rowSty = [centerStyle, centerStyle, centerStyle];

          if (includeCustomerDetails) {
            rowVals.add(TextCellValue(i == 0 ? custName : ''));
            rowSty.add(textStyle);
            rowVals.add(TextCellValue(i == 0 ? phone : ''));
            rowSty.add(centerStyle);
            rowVals.add(TextCellValue(i == 0 ? gstin : ''));
            rowSty.add(centerStyle);
          }

          if (includeTransactionType) {
            rowVals.add(TextCellValue(i == 0 ? (inv.status == 'PAID' ? 'Sale (Paid)' : 'Sale Bill') : ''));
            rowSty.add(centerStyle);
            rowVals.add(TextCellValue(i == 0 ? (inv.paymentType.isNotEmpty ? inv.paymentType : 'Cash') : ''));
            rowSty.add(centerStyle);
          }

          // Item columns
          rowVals.add(TextCellValue(it.name));
          rowSty.add(textStyle);
          rowVals.add(DoubleCellValue(it.quantity));
          rowSty.add(numStyle);
          rowVals.add(TextCellValue(it.unit));
          rowSty.add(centerStyle);
          rowVals.add(DoubleCellValue(it.rate));
          rowSty.add(numStyle);
          rowVals.add(DoubleCellValue(it.total));
          rowSty.add(numStyle);

          if (includeTaxDetails) {
            rowVals.add(DoubleCellValue(i == 0 ? inv.totalTax : 0.0));
            rowSty.add(numStyle);
          }

          rowVals.add(DoubleCellValue(i == 0 ? inv.grandTotal : 0.0));
          rowSty.add(numStyle);

          if (includePaymentDetails) {
            rowVals.add(DoubleCellValue(i == 0 ? inv.amountPaid : 0.0));
            rowSty.add(paidNumStyle);
          }

          if (includeOverAmounts) {
            rowVals.add(DoubleCellValue(i == 0 ? excess : 0.0));
            rowSty.add(numStyle);
          }

          if (includeBalances) {
            rowVals.add(DoubleCellValue(i == 0 ? inv.balanceDue : 0.0));
            rowSty.add(dueNumStyle);
            rowVals.add(TextCellValue(i == 0 ? (isPaid ? 'PAID' : (isPartial ? 'PARTIAL' : 'DUE')) : ''));
            rowSty.add(statusStyle);
          }

          rowVals.add(TextCellValue(i == 0 ? (inv.description.isNotEmpty ? inv.description : inv.notes) : ''));
          rowSty.add(textStyle);

          writeRow(rowVals, rowSty);
        }
        slNo++;
      } else {
        // Single clean summary row per invoice
        final List<CellValue> rowVals = [
          IntCellValue(slNo++),
          TextCellValue(dfmt.format(inv.invoiceDate)),
          TextCellValue('#${inv.invoiceNumber}'),
        ];
        final List<CellStyle> rowSty = [centerStyle, centerStyle, centerStyle];

        if (includeCustomerDetails) {
          rowVals.add(TextCellValue(custName));
          rowSty.add(textStyle);
          rowVals.add(TextCellValue(phone));
          rowSty.add(centerStyle);
          rowVals.add(TextCellValue(gstin));
          rowSty.add(centerStyle);
        }

        if (includeTransactionType) {
          rowVals.add(TextCellValue(isPaid ? 'Sale (Paid)' : (inv.amountPaid > 0 ? 'Sale (Partial)' : 'Sale (Due)')));
          rowSty.add(centerStyle);
          rowVals.add(TextCellValue(inv.paymentType.isNotEmpty ? inv.paymentType : 'Cash'));
          rowSty.add(centerStyle);
        }

        if (includeItemizedBreakdown) {
          final itemSummary = inv.items.map((it) => '${it.name} (${it.quantity}${it.unit})').join(', ');
          rowVals.add(TextCellValue(itemSummary));
          rowSty.add(textStyle);
          rowVals.add(DoubleCellValue(inv.items.fold<double>(0.0, (s, it) => s + it.quantity)));
          rowSty.add(numStyle);
          rowVals.add(TextCellValue('PCS'));
          rowSty.add(centerStyle);
          rowVals.add(DoubleCellValue(0.0));
          rowSty.add(numStyle);
          rowVals.add(DoubleCellValue(inv.subtotal));
          rowSty.add(numStyle);
        }

        if (includeTaxDetails) {
          rowVals.add(DoubleCellValue(inv.totalTax));
          rowSty.add(numStyle);
        }

        rowVals.add(DoubleCellValue(inv.grandTotal));
        rowSty.add(numStyle);

        if (includePaymentDetails) {
          rowVals.add(DoubleCellValue(inv.amountPaid));
          rowSty.add(paidNumStyle);
        }

        if (includeOverAmounts) {
          rowVals.add(DoubleCellValue(excess));
          rowSty.add(numStyle);
        }

        if (includeBalances) {
          rowVals.add(DoubleCellValue(inv.balanceDue));
          rowSty.add(dueNumStyle);
          rowVals.add(TextCellValue(isPaid ? 'PAID' : (isPartial ? 'PARTIAL' : 'DUE')));
          rowSty.add(statusStyle);
        }

        rowVals.add(TextCellValue(inv.description.isNotEmpty ? inv.description : inv.notes));
        rowSty.add(textStyle);

        writeRow(rowVals, rowSty);
      }
    }

    // ─── 4. Grand Totals & Summary Row ─────────────────────────────────────────
    if (includeGrandTotals) {
      // Empty spacing row
      currentRow++;

      final totalHeaderStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: totalTopBorder,
        bottomBorder: totalBottomBorder,
      );

      final totalEmptyStyle = CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        topBorder: totalTopBorder,
        bottomBorder: totalBottomBorder,
      );

      final totalNumStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#0F172A'),
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        topBorder: totalTopBorder,
        bottomBorder: totalBottomBorder,
      );

      final totalPaidStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#15803D'),
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        topBorder: totalTopBorder,
        bottomBorder: totalBottomBorder,
      );

      final totalDueStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString(totalDue > 0 ? '#B91C1C' : '#15803D'),
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        topBorder: totalTopBorder,
        bottomBorder: totalBottomBorder,
      );

      final totalStatusStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString(totalDue == 0 ? '#15803D' : '#B91C1C'),
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        topBorder: totalTopBorder,
        bottomBorder: totalBottomBorder,
      );

      final List<CellValue> totalsRowVals = [
        TextCellValue('TOTALS'),
        TextCellValue(''),
        TextCellValue('${sorted.length} Entries'),
      ];
      final List<CellStyle> totalsRowSty = [totalHeaderStyle, totalEmptyStyle, totalHeaderStyle];

      if (includeCustomerDetails) {
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
      }

      if (includeTransactionType) {
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
      }

      if (includeItemizedBreakdown) {
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
        totalsRowVals.add(TextCellValue(''));
        totalsRowSty.add(totalEmptyStyle);
      }

      if (includeTaxDetails) {
        totalsRowVals.add(DoubleCellValue(totalTaxAmt));
        totalsRowSty.add(totalNumStyle);
      }

      totalsRowVals.add(DoubleCellValue(totalBilled));
      totalsRowSty.add(totalNumStyle);

      if (includePaymentDetails) {
        totalsRowVals.add(DoubleCellValue(totalPaid));
        totalsRowSty.add(totalPaidStyle);
      }

      if (includeOverAmounts) {
        totalsRowVals.add(DoubleCellValue(totalOver));
        totalsRowSty.add(totalNumStyle);
      }

      if (includeBalances) {
        totalsRowVals.add(DoubleCellValue(totalDue));
        totalsRowSty.add(totalDueStyle);
        totalsRowVals.add(TextCellValue(totalDue == 0 ? 'ALL SETTLED' : 'PENDING DUES'));
        totalsRowSty.add(totalStatusStyle);
      }

      totalsRowVals.add(TextCellValue(''));
      totalsRowSty.add(totalEmptyStyle);

      writeRow(totalsRowVals, totalsRowSty);
    }

    // ─── 5. Auto Column Widths ─────────────────────────────────────────────────
    for (int col = 0; col < headerValues.length; col++) {
      sheet.setColumnWidth(col, 20.0);
    }
    sheet.setColumnWidth(0, 8.0);   // Sl No
    sheet.setColumnWidth(1, 14.0);  // Date
    sheet.setColumnWidth(2, 16.0);  // Voucher #
    if (includeCustomerDetails) {
      sheet.setColumnWidth(3, 26.0); // Party Name
      sheet.setColumnWidth(4, 16.0); // Phone
      sheet.setColumnWidth(5, 18.0); // GSTIN
    }

    final fileBytes = excel.save();
    return Uint8List.fromList(fileBytes ?? []);
  }

  /// Generate an editable Excel (.xlsx) file for Party Statement / Customer Account Ledger
  static Future<Uint8List> generatePartyStatementExcel({
    required CustomerModel customer,
    required List<InvoiceModel> allInvoices,
    required DateTime fromDate,
    required DateTime toDate,
    BusinessModel? business,
  }) async {
    return generateCustomXlsx(
      invoices: allInvoices,
      fromDate: fromDate,
      toDate: toDate,
      business: business,
      specificCustomer: customer,
      reportTitle: 'PARTY ACCOUNT LEDGER STATEMENT',
      includeCompanyHeader: true,
      includeCustomerDetails: true,
      includeTransactionType: true,
      includeItemizedBreakdown: false,
      includeTaxDetails: false,
      includePaymentDetails: true,
      includeOverAmounts: true,
      includeBalances: true,
      includeGrandTotals: true,
    );
  }

  /// Generate an editable Excel (.xlsx) file for Date-Wise General Ledger & Daybook (All Transactions)
  static Future<Uint8List> generateGeneralLedgerExcel({
    required List<InvoiceModel> invoices,
    required DateTime fromDate,
    required DateTime toDate,
    BusinessModel? business,
    String? partyFilterName,
  }) async {
    return generateCustomXlsx(
      invoices: invoices,
      fromDate: fromDate,
      toDate: toDate,
      business: business,
      reportTitle: 'DATE-WISE GENERAL LEDGER & DAYBOOK',
      includeCompanyHeader: true,
      includeCustomerDetails: true,
      includeTransactionType: true,
      includeItemizedBreakdown: false,
      includeTaxDetails: false,
      includePaymentDetails: true,
      includeOverAmounts: true,
      includeBalances: true,
      includeGrandTotals: true,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  /// Party-wise transaction ledger matching ex.xlsx format exactly:
  /// Columns: DATE | DESCRIPTION | CREDIT | DEBIT
  /// - Bill / Purchase / Sale row → Debit in Blue
  /// - Payment row → Credit in Red
  /// - Settlement subtotal + SETTLEMENT banner
  /// - No extra company headers, no party info box, no extra columns.
  // ────────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generatePartyLedgerXlsx({
    required CustomerModel customer,
    required List<InvoiceModel> allInvoices,
    required DateTime fromDate,
    required DateTime toDate,
    BusinessModel? business,
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[defaultSheet];

    final dfmt = DateFormat('dd/MM/yy');

    int row = 0;

    void writeRow(List<CellValue> vals, List<CellStyle> styles) {
      for (int c = 0; c < vals.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
        cell.value = vals[c];
        if (c < styles.length) cell.cellStyle = styles[c];
      }
      row++;
    }

    String formatAmount(double amt) {
      if (amt == amt.roundToDouble()) {
        return '${amt.toInt()}/-';
      }
      return '${amt.toStringAsFixed(2)}/-';
    }

    // ── Styles matching ex.xlsx ───────────────────────────────────────────────
    final headerLeftStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final headerRightStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Debit rows (Sale / Purchase / Exp) in Blue (#0000FF)
    final debitDateStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0000FF'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final debitDescStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0000FF'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final debitAmountStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0000FF'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Credit rows (Payment received) in Red (#FF0000)
    final creditDateStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FF0000'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final creditDescStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FF0000'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final creditAmountStyle = CellStyle(
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FF0000'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Totals: Bold Red Credit, Bold Blue Debit
    final boldCreditTotalStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FF0000'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    final boldDebitTotalStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#0000FF'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Settlement Banner: Bold Center Black
    final settlementStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final blankStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // ── 1. Header Row: DATE | DESCRIPTION | CREDIT | DEBIT ─────────────────────
    writeRow(
      [
        TextCellValue('DATE'),
        TextCellValue('DESCRIPTION '),
        TextCellValue('CREDIT'),
        TextCellValue('DEBIT'),
      ],
      [
        headerLeftStyle,
        headerLeftStyle,
        headerRightStyle,
        headerRightStyle,
      ],
    );

    // ── 2. Filter & Sort Invoices ─────────────────────────────────────────────
    final fromStart = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final toEnd = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

    final periodInvoices = allInvoices
        .where((inv) =>
            inv.customerId == customer.id &&
            !inv.invoiceDate.isBefore(fromStart) &&
            !inv.invoiceDate.isAfter(toEnd))
        .toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    final bShort = business?.businessName.isNotEmpty == true
        ? business!.businessName.split(' ').first.toUpperCase()
        : 'JMJ';
    final pName = customer.name.toUpperCase();

    double totalDebit = 0;
    double totalCredit = 0;

    if (periodInvoices.isEmpty) {
      writeRow(
        [
          TextCellValue(dfmt.format(fromDate)),
          TextCellValue('NO TRANSACTIONS'),
          TextCellValue(''),
          TextCellValue(''),
        ],
        [
          debitDateStyle,
          debitDescStyle,
          blankStyle,
          blankStyle,
        ],
      );
    } else {
      for (final inv in periodInvoices) {
        final dateStr = dfmt.format(inv.invoiceDate);

        // Determine description for bill
        String billDesc = '';
        if (inv.description.isNotEmpty) {
          billDesc = inv.description.toUpperCase();
        } else if (inv.items.isNotEmpty) {
          billDesc = inv.items.map((it) {
            final q = it.quantity == it.quantity.roundToDouble()
                ? it.quantity.toInt().toString()
                : it.quantity.toString();
            return '${it.name.toUpperCase()} × $q ${it.unit.toUpperCase()}';
          }).join(', ');
        } else {
          billDesc = 'PUR + EXP';
        }

        // 1. Debit row: Bill / Sale
        totalDebit += inv.grandTotal;
        writeRow(
          [
            TextCellValue(dateStr),
            TextCellValue(billDesc),
            TextCellValue(''),
            TextCellValue(formatAmount(inv.grandTotal)),
          ],
          [
            debitDateStyle,
            debitDescStyle,
            blankStyle,
            debitAmountStyle,
          ],
        );

        // 2. Credit row: Payment received (if any)
        if (inv.amountPaid > 0) {
          totalCredit += inv.amountPaid;
          final payMode = inv.paymentType.isNotEmpty ? inv.paymentType.toUpperCase() : 'CASH';
          final payDesc = '$bShort TO $pName $payMode PAID';

          writeRow(
            [
              TextCellValue(dateStr),
              TextCellValue(payDesc),
              TextCellValue(formatAmount(inv.amountPaid)),
              TextCellValue(''),
            ],
            [
              creditDateStyle,
              creditDescStyle,
              creditAmountStyle,
              blankStyle,
            ],
          );
        }

        // 3. Settlement block if bill is fully paid
        if (inv.amountPaid > 0 && inv.balanceDue <= 0) {
          // Totals for this settlement
          writeRow(
            [
              TextCellValue(''),
              TextCellValue(''),
              TextCellValue(formatAmount(inv.amountPaid)),
              TextCellValue(formatAmount(inv.grandTotal)),
            ],
            [
              blankStyle,
              blankStyle,
              boldCreditTotalStyle,
              boldDebitTotalStyle,
            ],
          );

          // SETTLEMENT banner
          final sRow = row;
          writeRow(
            [
              TextCellValue('SETTLEMENT '),
              TextCellValue(''),
              TextCellValue(''),
              TextCellValue(''),
            ],
            [
              settlementStyle,
              settlementStyle,
              settlementStyle,
              settlementStyle,
            ],
          );
          try {
            sheet.merge(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sRow),
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sRow),
            );
          } catch (_) {}
        }
      }

      // If multiple invoices exist, show grand summary at the end
      if (periodInvoices.length > 1) {
        writeRow(
          [
            TextCellValue(''),
            TextCellValue('TOTAL'),
            TextCellValue(formatAmount(totalCredit)),
            TextCellValue(formatAmount(totalDebit)),
          ],
          [
            blankStyle,
            headerLeftStyle,
            boldCreditTotalStyle,
            boldDebitTotalStyle,
          ],
        );

        if (totalDebit > totalCredit) {
          final diff = totalDebit - totalCredit;
          writeRow(
            [
              TextCellValue(''),
              TextCellValue('BALANCE DUE'),
              TextCellValue(''),
              TextCellValue(formatAmount(diff)),
            ],
            [
              blankStyle,
              headerLeftStyle,
              blankStyle,
              boldDebitTotalStyle,
            ],
          );
        } else if (totalDebit <= totalCredit && totalDebit > 0) {
          // All settled — show a final SETTLEMENT banner only if not already shown per-invoice
          final allSettled = periodInvoices.every((inv) => inv.balanceDue <= 0);
          if (!allSettled) {
            // Partially settled across invoices — no redundant SETTLEMENT banner
          }
        }
      } else if (periodInvoices.length == 1 && periodInvoices.first.balanceDue > 0) {
        // Single invoice with balance pending
        writeRow(
          [
            TextCellValue(''),
            TextCellValue('BALANCE DUE'),
            TextCellValue(''),
            TextCellValue(formatAmount(periodInvoices.first.balanceDue)),
          ],
          [
            blankStyle,
            headerLeftStyle,
            blankStyle,
            boldDebitTotalStyle,
          ],
        );
      }
    }

    // ── 3. Set Column Widths for readability in Excel without zooming ──────────
    sheet.setColumnWidth(0, 16.0); // DATE — wider for readability
    sheet.setColumnWidth(1, 42.0); // DESCRIPTION — much wider for full text
    sheet.setColumnWidth(2, 18.0); // CREDIT — wider numbers
    sheet.setColumnWidth(3, 18.0); // DEBIT — wider numbers

    final fileBytes = excel.save();
    return Uint8List.fromList(fileBytes ?? []);
  }
}
