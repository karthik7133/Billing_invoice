import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/pdf_invoice_service.dart';
import '../../services/share_service.dart';
import '../../widgets/pdf_display_options_sheet.dart';
import '../invoices/invoice_detail_screen.dart';

class PartyStatementScreen extends StatefulWidget {
  final CustomerModel customer;

  const PartyStatementScreen({super.key, required this.customer});

  @override
  State<PartyStatementScreen> createState() => _PartyStatementScreenState();
}

typedef _RangeLabel = String;

class _PartyStatementScreenState extends State<PartyStatementScreen> {
  _RangeLabel _selectedRange = 'This Month';
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  // View mode: 0 = Multi-Column Table, 1 = Card List
  int _viewMode = 0;

  // PDF display options
  bool _showItemDetails = true;
  bool _showDescription = false;
  bool _showPaymentStatus = false;
  bool _showPaymentInfo = true;
  String _pdfFileName = '';

  final List<String> _rangeOptions = [
    'This Month',
    'Last Month',
    'This Quarter',
    'This Year',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _applyRange('This Month');
    _pdfFileName = _buildDefaultFileName();
  }

  String _buildDefaultFileName() {
    final name = widget.customer.name.replaceAll(' ', '_').replaceAll('/', '_');
    final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
    return 'Statement_${name}_$date';
  }

  void _applyRange(String label) {
    final now = DateTime.now();
    setState(() {
      _selectedRange = label;
      switch (label) {
        case 'This Month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'Last Month':
          _fromDate = DateTime(now.year, now.month - 1, 1);
          _toDate = DateTime(now.year, now.month, 0);
          break;
        case 'This Quarter':
          final q = ((now.month - 1) ~/ 3) * 3 + 1;
          _fromDate = DateTime(now.year, q, 1);
          _toDate = DateTime(now.year, q + 3, 0);
          break;
        case 'This Year':
          _fromDate = DateTime(now.year, 1, 1);
          _toDate = DateTime(now.year, 12, 31);
          break;
        default:
          break;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          _selectedRange = 'Custom';
        } else {
          _toDate = picked;
          _selectedRange = 'Custom';
        }
      });
    }
  }

  /// Build accurate running balance rows for the ledger
  List<_StatementRow> _buildRows({
    required CustomerModel customer,
    required List<InvoiceModel> allInvoices,
  }) {
    final rows = <_StatementRow>[];

    // Sort all invoices chronologically
    final sortedAll = List<InvoiceModel>.from(allInvoices)
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    final fromStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toEnd = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    // 1. Calculate opening balance accumulated before fromDate
    double balance = customer.openingBalance;
    for (final inv in sortedAll) {
      if (inv.invoiceDate.isBefore(fromStart)) {
        balance += (inv.grandTotal - inv.amountPaid);
      }
    }

    // 2. Opening balance row at start of selected period
    rows.add(_StatementRow(
      date: fromStart,
      type: 'Opening Balance',
      refNo: '-',
      billAmount: null,
      receivedAmount: null,
      overAmount: null,
      balance: balance,
      isOpening: true,
    ));

    // 3. Filter invoices in the selected period
    final periodInvoices = sortedAll.where((inv) {
      return !inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd);
    }).toList();

    for (final inv in periodInvoices) {
      // (A) Purchase Bill Row
      balance += inv.grandTotal;
      rows.add(_StatementRow(
        date: inv.invoiceDate,
        type: 'Purchase',
        refNo: '#${inv.invoiceNumber}',
        billAmount: inv.grandTotal,
        receivedAmount: null,
        overAmount: null,
        balance: balance,
        invoice: inv,
      ));

      // (B) Payment Received Row (if customer paid on this invoice)
      if (inv.amountPaid > 0) {
        balance -= inv.amountPaid;
        final excess = inv.overMoneyAmount > 0 ? inv.overMoneyAmount : 0.0;
        rows.add(_StatementRow(
          date: inv.invoiceDate,
          type: 'Payment',
          refNo: '#${inv.invoiceNumber}',
          paymentMode: inv.paymentType.isNotEmpty ? inv.paymentType : 'Cash',
          billAmount: null,
          receivedAmount: inv.amountPaid,
          overAmount: excess > 0 ? excess : null,
          balance: balance,
          invoice: inv,
        ));
      }
    }

    return rows;
  }

  void _showPdfOptionsSheet(List<InvoiceModel> invoices) {
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final defaultFileName = _pdfFileName.isNotEmpty ? _pdfFileName : _buildDefaultFileName();

    PdfDisplayOptionsSheet.show(
      context,
      defaultFileName: defaultFileName,
      initialShowItemDetails: _showItemDetails,
      initialShowDescription: _showDescription,
      initialShowPaymentStatus: _showPaymentStatus,
      initialShowPaymentInfo: _showPaymentInfo,
      onApply: ({
        required String fileName,
        required bool showItemDetails,
        required bool showDescription,
        required bool showPaymentStatus,
        required bool showPaymentInfo,
      }) async {
        setState(() {
          _pdfFileName = fileName;
          _showItemDetails = showItemDetails;
          _showDescription = showDescription;
          _showPaymentStatus = showPaymentStatus;
          _showPaymentInfo = showPaymentInfo;
        });

        final messenger = ScaffoldMessenger.of(context);
        try {
          final bytes = await PdfInvoiceService.generatePartyStatementPdf(
            customer: widget.customer,
            invoices: invoices,
            fromDate: _fromDate,
            toDate: _toDate,
            business: businessProvider.business,
            showItemDetails: showItemDetails,
            showDescription: showDescription,
            showPaymentStatus: showPaymentStatus,
            showPaymentInfo: showPaymentInfo,
          );
          final finalName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
          await ShareService.sharePdf(bytes, filename: finalName);
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error generating PDF: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  void _shareAsXls(List<InvoiceModel> allInvoices, List<_StatementRow> rows, double closingBalance) {
    HapticFeedback.lightImpact();
    final buf = StringBuffer();
    buf.writeln('PARTY STATEMENT');
    buf.writeln('Party Name: ${widget.customer.name}');
    if (widget.customer.phone.isNotEmpty) buf.writeln('Phone: ${widget.customer.phone}');
    buf.writeln('Period: ${DateFormat('dd/MM/yyyy').format(_fromDate)} to ${DateFormat('dd/MM/yyyy').format(_toDate)}');
    buf.writeln('');
    buf.writeln('Date,Transaction Type,Ref / Bill No.,Bill Amount (₹),Received Amount (₹),Over Amount (₹),Running Balance (₹)');

    for (final r in rows) {
      final dStr = DateFormat('dd/MM/yyyy').format(r.date);
      final bAmt = r.billAmount != null ? r.billAmount!.toStringAsFixed(2) : '';
      final rAmt = r.receivedAmount != null ? r.receivedAmount!.toStringAsFixed(2) : '';
      final oAmt = r.overAmount != null ? r.overAmount!.toStringAsFixed(2) : '';
      final balStr = '${r.balance.abs().toStringAsFixed(2)} ${r.balance > 0 ? "Dr" : (r.balance < 0 ? "Cr" : "")}';

      buf.writeln('$dStr,${r.type},${r.refNo},$bAmt,$rAmt,$oAmt,$balStr');
    }

    buf.writeln('');
    buf.writeln('Closing Balance,,,${closingBalance.abs().toStringAsFixed(2)} ${closingBalance > 0 ? "Dr (Receivable)" : (closingBalance < 0 ? "Cr (Advance)" : "Settled")}');

    ShareService.shareText(
      text: buf.toString(),
      subject: 'Party Statement - ${widget.customer.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final allParty = invoiceProvider.getInvoicesForCustomer(widget.customer.id);
    final rows = _buildRows(customer: widget.customer, allInvoices: allParty);

    // Exact final closing balance is the last row's balance
    final closingBalance = rows.isNotEmpty ? rows.last.balance : 0.0;

    // Filtered invoices in period for PDF / totals
    final fromStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toEnd = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
    final periodInvoices = allParty.where((inv) {
      return !inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd);
    }).toList();

    final totalBilled = periodInvoices.fold<double>(0.0, (s, i) => s + i.grandTotal);
    final totalPaid = periodInvoices.fold<double>(0.0, (s, i) => s + i.amountPaid);
    final totalOverMoney = periodInvoices.fold<double>(0.0, (s, i) => s + i.overMoneyAmount);

    final isReceivable = closingBalance > 0;
    final isAdvance = closingBalance < 0;
    final isSettled = closingBalance == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Party Statement',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        actions: [
          // View Toggle: Table / Cards
          IconButton(
            icon: Icon(
              _viewMode == 0 ? Icons.view_agenda_outlined : Icons.table_chart_outlined,
              color: const Color(0xFF2563EB),
              size: 21,
            ),
            tooltip: _viewMode == 0 ? 'Switch to Card View' : 'Switch to Table View',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _viewMode = _viewMode == 0 ? 1 : 0);
            },
          ),
          // PDF Export Button
          _AppBarIconBtn(
            color: const Color(0xFFDC2626),
            label: 'PDF',
            onTap: () => _showPdfOptionsSheet(periodInvoices),
          ),
          const SizedBox(width: 6),
          // XLS Export Button
          _AppBarIconBtn(
            color: const Color(0xFF16A34A),
            label: 'XLS',
            onTap: () => _shareAsXls(allParty, rows, closingBalance),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // ─── 1. Date Range & Period Selector ───────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Range dropdown pill
                GestureDetector(
                  onTap: () => _showRangeSheet(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedRange,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                // From date
                GestureDetector(
                  onTap: () => _pickDate(isFrom: true),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_fromDate),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('TO', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
                ),
                // To date
                GestureDetector(
                  onTap: () => _pickDate(isFrom: false),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_toDate),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. Customer Header & Search Tag ───────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.customer.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.customer.phone.isNotEmpty)
                          Text(
                            widget.customer.phone,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 3. Accurate Closing Balance & 3-Stat Summary Card ─────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isAdvance ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Closing Balance + Status Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdvance
                                ? 'Closing Balance (Advance / Over-Paid)'
                                : (isReceivable ? 'Closing Balance (Due / Receivable)' : 'Closing Balance (Settled)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isAdvance ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(closingBalance.abs()),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isAdvance
                                  ? const Color(0xFF16A34A)
                                  : (isSettled ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAdvance
                              ? const Color(0xFFDCFCE7)
                              : (isSettled ? const Color(0xFFF1F5F9) : const Color(0xFFFEE2E2)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAdvance
                                  ? Icons.arrow_upward_rounded
                                  : (isSettled ? Icons.check_circle_outline : Icons.arrow_downward_rounded),
                              size: 13,
                              color: isAdvance
                                  ? const Color(0xFF16A34A)
                                  : (isSettled ? const Color(0xFF64748B) : const Color(0xFFDC2626)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAdvance
                                  ? "You'll Give"
                                  : (isSettled ? 'Settled' : "You'll Get"),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isAdvance
                                    ? const Color(0xFF16A34A)
                                    : (isSettled ? const Color(0xFF64748B) : const Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // 3-Stat Breakdown Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryStatPill(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Total Billed',
                        amount: CurrencyFormatter.format(totalBilled),
                        color: const Color(0xFF1E293B),
                        bgColor: const Color(0xFFF8FAFC),
                      ),
                      _buildSummaryStatPill(
                        icon: Icons.payments_outlined,
                        label: 'Total Received',
                        amount: CurrencyFormatter.format(totalPaid),
                        color: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFF0FDF4),
                      ),
                      if (totalOverMoney > 0)
                        _buildSummaryStatPill(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Over Amount',
                          amount: CurrencyFormatter.format(totalOverMoney),
                          color: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFFAF5FF),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── 4. Table / Cards Viewport ────────────────────────────────────
          Expanded(
            child: rows.isEmpty || (rows.length == 1 && rows.first.isOpening)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'No transactions in this period',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Adjust the date range to see transaction ledger',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : (_viewMode == 0
                    ? _buildHorizontalScrollableTable(rows)
                    : _buildCardListView(rows)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatPill({
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // ─── Multi-Column Horizontally Scrollable Ledger Table ──────────────────────

  Widget _buildHorizontalScrollableTable(List<_StatementRow> rows) {
    const tableWidth = 840.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            // Table Header Bar
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 90, child: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                  SizedBox(width: 140, child: Text('TXN TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                  SizedBox(width: 120, child: Text('BILL / REF #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                  SizedBox(width: 120, child: Text('BILL AMT (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                  SizedBox(width: 120, child: Text('RECEIVED (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                  SizedBox(width: 110, child: Text('OVER AMT (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                  SizedBox(width: 116, child: Text('BALANCE (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
                ],
              ),
            ),

            // Table Data Rows
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: rows.length,
                itemBuilder: (ctx, i) {
                  final row = rows[i];
                  final isEven = i % 2 == 0;
                  final isOpening = row.isOpening;
                  final isPurchase = row.type == 'Purchase';

                  final dateStr = DateFormat('dd MMM, yy').format(row.date);
                  final isPositiveBalance = row.balance > 0;
                  final isZeroBalance = row.balance == 0;

                  return InkWell(
                    onTap: row.invoice != null
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailScreen(invoice: row.invoice!),
                              ),
                            );
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isOpening
                            ? const Color(0xFFF1F5F9)
                            : (isEven ? Colors.white : const Color(0xFFF8FAFC)),
                        border: Border(
                          left: const BorderSide(color: Color(0xFFE2E8F0)),
                          right: const BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: BorderSide(
                            color: i == rows.length - 1 ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                            width: i == rows.length - 1 ? 1.5 : 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // 1. Date
                          SizedBox(
                            width: 90,
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isOpening ? FontWeight.w800 : FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),

                          // 2. Txn Type
                          SizedBox(
                            width: 140,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOpening
                                        ? const Color(0xFFE2E8F0)
                                        : (isPurchase ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isOpening
                                        ? 'OPENING'
                                        : (isPurchase ? 'PURCHASE' : 'PAYMENT'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isOpening
                                          ? const Color(0xFF475569)
                                          : (isPurchase ? const Color(0xFF2563EB) : const Color(0xFF16A34A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 3. Bill / Ref #
                          SizedBox(
                            width: 120,
                            child: Text(
                              row.refNo,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: row.invoice != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // 4. Bill Amount (Debit)
                          SizedBox(
                            width: 120,
                            child: Text(
                              row.billAmount != null
                                  ? CurrencyFormatter.format(row.billAmount!)
                                  : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),

                          // 5. Received Amount (Credit)
                          SizedBox(
                            width: 120,
                            child: Text(
                              row.receivedAmount != null
                                  ? CurrencyFormatter.format(row.receivedAmount!)
                                  : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),

                          // 6. Over Amount (Excess Paid on this bill)
                          SizedBox(
                            width: 110,
                            child: row.overAmount != null && row.overAmount! > 0
                                ? Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3E8FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFD8B4FE), width: 0.8),
                                      ),
                                      child: Text(
                                        '+₹${row.overAmount!.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF7C3AED),
                                        ),
                                      ),
                                    ),
                                  )
                                : const Text(
                                    '-',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                          ),

                          // 7. Running Balance (with Dr/Cr tag)
                          SizedBox(
                            width: 116,
                            child: Text(
                              isZeroBalance
                                  ? '₹ 0.00'
                                  : '${CurrencyFormatter.format(row.balance.abs())} ${isPositiveBalance ? "Dr" : "Cr"}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isPositiveBalance
                                    ? const Color(0xFFDC2626)
                                    : (isZeroBalance ? const Color(0xFF16A34A) : const Color(0xFF16A34A)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Alternative Card List View ───────────────────────────────────────────

  Widget _buildCardListView(List<_StatementRow> rows) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final row = rows[i];
        final isOpening = row.isOpening;
        final isPayment = row.type == 'Payment';
        final isPurchase = row.type == 'Purchase';
        final dateStr = DateFormat('dd MMM, yy').format(row.date);

        final isPositiveBalance = row.balance > 0;
        final isZeroBalance = row.balance == 0;

        return InkWell(
          onTap: row.invoice != null
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: row.invoice!)),
                  );
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOpening
                                ? const Color(0xFFF1F5F9)
                                : (isPurchase ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOpening ? 'OPENING' : (isPurchase ? 'PURCHASE' : 'PAYMENT RECEIVED'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isOpening
                                  ? const Color(0xFF475569)
                                  : (isPurchase ? const Color(0xFF2563EB) : const Color(0xFF16A34A)),
                            ),
                          ),
                        ),
                        if (row.refNo != '-') ...[
                          const SizedBox(width: 8),
                          Text(
                            row.refNo,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Amount (Billed / Paid)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPurchase ? 'Bill Amount' : (isPayment ? 'Paid / Received' : 'Starting'),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          row.billAmount != null
                              ? CurrencyFormatter.format(row.billAmount!)
                              : (row.receivedAmount != null
                                  ? CurrencyFormatter.format(row.receivedAmount!)
                                  : '₹ 0.00'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isPayment ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),

                    // Over Amount Badge if excess paid
                    if (row.overAmount != null && row.overAmount! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD8B4FE)),
                        ),
                        child: Column(
                          children: [
                            const Text('Over Paid', style: TextStyle(fontSize: 9, color: Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
                            Text(
                              '+${CurrencyFormatter.format(row.overAmount!)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                      ),

                    // Balance after this transaction
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Running Balance', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 1),
                        Text(
                          isZeroBalance
                              ? '₹ 0.00'
                              : '${CurrencyFormatter.format(row.balance.abs())} ${isPositiveBalance ? "Dr" : "Cr"}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isPositiveBalance
                                ? const Color(0xFFDC2626)
                                : (isZeroBalance ? const Color(0xFF16A34A) : const Color(0xFF16A34A)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRangeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Select Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              ),
              ..._rangeOptions.map(
                (opt) => ListTile(
                  title: Text(opt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: _selectedRange == opt
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyRange(opt);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Statement Ledger Row Model ───────────────────────────────────────────────

class _StatementRow {
  final DateTime date;
  final String type; // 'Opening Balance', 'Purchase', 'Payment'
  final String refNo;
  final String? paymentMode;
  final double? billAmount;
  final double? receivedAmount;
  final double? overAmount;
  final double balance;
  final bool isOpening;
  final InvoiceModel? invoice;

  _StatementRow({
    required this.date,
    required this.type,
    required this.refNo,
    this.paymentMode,
    this.billAmount,
    this.receivedAmount,
    this.overAmount,
    required this.balance,
    this.isOpening = false,
    this.invoice,
  });
}

// ─── AppBar Icon Button ────────────────────────────────────────────────────────

class _AppBarIconBtn extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _AppBarIconBtn({required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

