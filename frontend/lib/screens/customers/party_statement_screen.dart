import 'dart:math' as math;
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
import '../../providers/customer_provider.dart';
import '../../services/pdf_invoice_service.dart';
import '../../services/share_service.dart';
import '../../widgets/pdf_display_options_sheet.dart';
import '../../widgets/pdf_progress_dialog.dart';
import '../../widgets/xls_export_options_sheet.dart';
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

  // PDF & On-screen display options
  bool _showItemDetails = true;
  bool _showDescription = false;
  bool _showPaymentStatus = false;
  bool _showPaymentInfo = true;
  String _pdfFileName = '';

  // Payment status filter: 'All', 'Paid', 'Pending', 'Partial'
  String _selectedPaymentStatusFilter = 'All';

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
    required String statusFilter,
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
        balance += inv.grandTotal;
      }
      if (inv.payments.isNotEmpty) {
        for (final p in inv.payments) {
          if (p.date.isBefore(fromStart)) {
            balance -= p.amount;
          }
        }
      } else if (inv.amountPaid > 0 && inv.invoiceDate.isBefore(fromStart)) {
        balance -= inv.amountPaid;
      }
    }

    // 2. Opening balance row at start of selected period (included in 'All' mode)
    if (statusFilter == 'All') {
      rows.add(_StatementRow(
        date: fromStart,
        type: 'Opening Balance',
        refNo: '-',
        description: 'Opening balance before ${DateFormat('dd MMM yyyy').format(fromStart)}',
        paymentStatus: '-',
        billAmount: null,
        receivedAmount: null,
        overAmount: null,
        balance: balance,
        isOpening: true,
      ));
    }

    // 3. Collect all period transactions (Purchases & split Payments)
    final periodEntries = <_StatementRow>[];

    for (final inv in sortedAll) {
      // Apply status filter
      if (statusFilter == 'Paid' && !inv.isPaid) continue;
      if (statusFilter == 'Pending' && (inv.isPaid || inv.totalReceived > 0)) continue;
      if (statusFilter == 'Partial' && (inv.isPaid || inv.totalReceived == 0)) continue;

      final invDesc = inv.description.isNotEmpty
          ? inv.description
          : (inv.items.isNotEmpty ? inv.items.map((e) => e.name).take(2).join(', ') : '-');
      final invStatus = inv.isPaid ? 'PAID' : (inv.totalReceived > 0 ? 'PARTIAL' : 'PENDING');

      // (A) Purchase Bill Row (if issued in period)
      if (!inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd)) {
        periodEntries.add(_StatementRow(
          date: inv.invoiceDate,
          type: 'Purchase',
          refNo: '#${inv.invoiceNumber}',
          description: invDesc,
          paymentStatus: invStatus,
          billAmount: inv.grandTotal,
          receivedAmount: null,
          overAmount: null,
          balance: 0,
          invoice: inv,
        ));
      }

      // (B) Payment Rows (if customer paid on this invoice)
      if (statusFilter != 'Pending') {
        if (inv.payments.isNotEmpty) {
          for (final p in inv.payments) {
            if (!p.date.isBefore(fromStart) && !p.date.isAfter(toEnd)) {
              final excess = inv.overMoneyAmount > 0 ? inv.overMoneyAmount : 0.0;
              final pMode = p.type.isNotEmpty ? p.type : (inv.paymentType.isNotEmpty ? inv.paymentType : 'Cash');
              final pDesc = p.notes.isNotEmpty ? 'Payment via $pMode (${p.notes})' : 'Payment via $pMode';
              periodEntries.add(_StatementRow(
                date: p.date,
                type: 'Payment',
                refNo: '#${inv.invoiceNumber}',
                paymentMode: pMode,
                description: pDesc,
                paymentStatus: 'PAID',
                billAmount: null,
                receivedAmount: p.amount,
                overAmount: excess > 0 ? excess : null,
                balance: 0,
                invoice: inv,
              ));
            }
          }
        } else if (inv.amountPaid > 0) {
          // Fallback for legacy invoice without payments array
          if (!inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd)) {
            final excess = inv.overMoneyAmount > 0 ? inv.overMoneyAmount : 0.0;
            periodEntries.add(_StatementRow(
              date: inv.invoiceDate,
              type: 'Payment',
              refNo: '#${inv.invoiceNumber}',
              paymentMode: inv.paymentType.isNotEmpty ? inv.paymentType : 'Cash',
              description: inv.paymentType.isNotEmpty ? 'Payment via ${inv.paymentType}' : 'Payment received',
              paymentStatus: 'PAID',
              billAmount: null,
              receivedAmount: inv.amountPaid,
              overAmount: excess > 0 ? excess : null,
              balance: 0,
              invoice: inv,
            ));
          }
        }
      }
    }

    // 4. Sort period transactions chronologically (Purchase before Payment on same date)
    periodEntries.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      if (a.type == 'Purchase' && b.type != 'Purchase') return -1;
      if (a.type != 'Purchase' && b.type == 'Purchase') return 1;
      return 0;
    });

    // 5. Sequentially calculate running balance
    for (final entry in periodEntries) {
      if (entry.type == 'Purchase') {
        balance += (entry.billAmount ?? 0);
      } else if (entry.type == 'Payment') {
        balance -= (entry.receivedAmount ?? 0);
      }

      rows.add(_StatementRow(
        date: entry.date,
        type: entry.type,
        refNo: entry.refNo,
        paymentMode: entry.paymentMode,
        description: entry.description,
        paymentStatus: entry.paymentStatus,
        billAmount: entry.billAmount,
        receivedAmount: entry.receivedAmount,
        overAmount: entry.overAmount,
        balance: balance,
        invoice: entry.invoice,
        isOpening: false,
      ));
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
        PdfProgressDialog.show(context, message: 'Preparing Statement PDF...');
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
          PdfProgressDialog.hide();
          await Future.delayed(const Duration(milliseconds: 100));
          final finalName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
          await ShareService.sharePdf(bytes, filename: finalName);
        } catch (e) {
          PdfProgressDialog.hide();
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

  void _shareAsXls(List<InvoiceModel> allInvoices) {
    HapticFeedback.lightImpact();
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    XlsExportOptionsSheet.show(
      context,
      allInvoices: allInvoices,
      customers: customerProvider.customers,
      business: businessProvider.business,
      currentFromDate: _fromDate,
      currentToDate: _toDate,
      preselectedParty: widget.customer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final allParty = invoiceProvider.getInvoicesForCustomer(widget.customer.id);
    final rows = _buildRows(
      customer: widget.customer,
      allInvoices: allParty,
      statusFilter: _selectedPaymentStatusFilter,
    );

    // Exact final closing balance is the last row's balance
    final closingBalance = rows.isNotEmpty ? rows.last.balance : 0.0;

    // Filtered invoices in period for PDF / totals / filter counters
    final fromStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toEnd = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
    final periodInvoices = allParty.where((inv) {
      return !inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd);
    }).toList();

    final totalInvoicesCount = periodInvoices.length;
    final paidCount = periodInvoices.where((i) => i.isPaid).length;
    final pendingCount = periodInvoices.where((i) => !i.isPaid && i.totalReceived == 0).length;
    final partialCount = periodInvoices.where((i) => !i.isPaid && i.totalReceived > 0).length;

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
          // PDF Export Button with hover effect
          _AppBarIconBtn(
            color: const Color(0xFFDC2626),
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
            tooltip: 'Export statement as PDF document',
            onTap: () => _showPdfOptionsSheet(periodInvoices),
          ),
          const SizedBox(width: 8),
          // XLS Export Button with hover effect
          _AppBarIconBtn(
            color: const Color(0xFF16A34A),
            label: 'XLS',
            icon: Icons.table_view_rounded,
            tooltip: 'Export statement as Excel (.xlsx)',
            onTap: () => _shareAsXls(allParty),
          ),
          const SizedBox(width: 12),
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
                      Expanded(
                        child: Column(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                    children: [
                      _buildSummaryStatPill(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Total Billed',
                        amount: CurrencyFormatter.format(totalBilled),
                        color: const Color(0xFF1E293B),
                        bgColor: const Color(0xFFF8FAFC),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryStatPill(
                        icon: Icons.payments_outlined,
                        label: 'Total Received',
                        amount: CurrencyFormatter.format(totalPaid),
                        color: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFF0FDF4),
                      ),
                      if (totalOverMoney > 0) ...[
                        const SizedBox(width: 6),
                        _buildSummaryStatPill(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Over Amount',
                          amount: CurrencyFormatter.format(totalOverMoney),
                          color: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFFAF5FF),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── 3.5. Payment Status Filter & Display Options Toolbar ─────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth > 700;
                final statusFilters = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      const Text(
                        'Status:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('All', 'All ($totalInvoicesCount)', const Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Paid', 'Paid ($paidCount)', const Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Pending', 'Pending ($pendingCount)', const Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip('Partial', 'Partial ($partialCount)', const Color(0xFFD97706)),
                    ],
                  ),
                );

                final displayToggles = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    const Text(
                      'Columns:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 8),
                    _buildToggleChip(
                      label: 'Description',
                      icon: Icons.notes_rounded,
                      isActive: _showDescription,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showDescription = !_showDescription);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildToggleChip(
                      label: 'Payment Status',
                      icon: Icons.verified_outlined,
                      isActive: _showPaymentStatus,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showPaymentStatus = !_showPaymentStatus);
                      },
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: statusFilters),
                      const SizedBox(width: 16),
                      displayToggles,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      statusFilters,
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 8),
                      displayToggles,
                    ],
                  );
                }
              },
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
                        Text(
                          _selectedPaymentStatusFilter != 'All'
                              ? 'No $_selectedPaymentStatusFilter transactions in this period'
                              : 'No transactions in this period',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedPaymentStatusFilter != 'All'
                              ? 'Try selecting "All" or adjusting the date range'
                              : 'Adjust the date range to see transaction ledger',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                        if (_selectedPaymentStatusFilter != 'All') ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _selectedPaymentStatusFilter = 'All'),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Reset Filter to All'),
                          ),
                        ],
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String key, String label, Color activeColor) {
    final isSelected = _selectedPaymentStatusFilter == key;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPaymentStatusFilter = key);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
              width: isActive ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 15,
                color: isActive ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status;

    switch (status) {
      case 'PAID':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'PARTIAL':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'PENDING':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = '-';
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
        ),
      ),
    );
  }

  // ─── Multi-Column Horizontally Scrollable Ledger Table ──────────────────────

  Widget _buildHorizontalScrollableTable(List<_StatementRow> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final bool isDesktop = availableWidth > 750;

        int maxRefLength = 0;
        for (final r in rows) {
          if (r.refNo.length > maxRefLength) {
            maxRefLength = r.refNo.length;
          }
        }

        // Base column widths
        final double baseDateWidth = isDesktop ? 105.0 : 85.0;
        final double baseTxnWidth = isDesktop ? 100.0 : 82.0;
        final double baseRefWidth = (maxRefLength * 8.0 + (isDesktop ? 32 : 24)).clamp(isDesktop ? 95.0 : 75.0, 150.0);
        final double baseDescWidth = _showDescription ? (isDesktop ? 220.0 : 160.0) : 0.0;
        final double baseStatusWidth = _showPaymentStatus ? (isDesktop ? 110.0 : 90.0) : 0.0;
        final double baseBillAmtWidth = isDesktop ? 120.0 : 98.0;
        final double baseReceivedWidth = isDesktop ? 120.0 : 98.0;
        final double baseOverAmtWidth = isDesktop ? 100.0 : 84.0;
        final double baseBalanceWidth = isDesktop ? 140.0 : 110.0;

        final double baseTotal = baseDateWidth +
            baseTxnWidth +
            baseRefWidth +
            baseDescWidth +
            baseStatusWidth +
            baseBillAmtWidth +
            baseReceivedWidth +
            baseOverAmtWidth +
            baseBalanceWidth;

        // Horizontal spacing around the table:
        // Left & right outer margins = 12px each (24px total)
        // Left & right inner container cell padding = 14px each (28px total)
        const double horizontalMargins = 24.0;
        const double horizontalCellPadding = 28.0;
        const double totalHorizontalOverhead = horizontalMargins + horizontalCellPadding;

        // Content width available for all table columns inside the container
        final double availableContentWidth = availableWidth - totalHorizontalOverhead;

        // Distribute extra width proportionally to columns when availableContentWidth > baseTotal
        final double extraWidth = math.max(0.0, availableContentWidth - baseTotal);

        double extraDesc = 0;
        double extraRef = 0;
        double extraAmt = 0;
        double extraBal = 0;

        if (extraWidth > 0) {
          if (_showDescription) {
            extraDesc = extraWidth * 0.35;
            extraBal = extraWidth * 0.25;
            extraAmt = extraWidth * 0.10; // applied to 2 amount columns = 0.20
            extraRef = extraWidth * 0.20;
          } else {
            extraBal = extraWidth * 0.30;
            extraAmt = extraWidth * 0.15; // applied to 2 amount columns = 0.30
            extraRef = extraWidth * 0.40;
          }
        }

        final double dateColWidth = baseDateWidth;
        final double txnColWidth = baseTxnWidth;
        final double refColWidth = baseRefWidth + extraRef;
        final double descColWidth = baseDescWidth + extraDesc;
        final double statusColWidth = baseStatusWidth;
        final double billAmtColWidth = baseBillAmtWidth + extraAmt;
        final double receivedColWidth = baseReceivedWidth + extraAmt;
        final double overAmtColWidth = baseOverAmtWidth;

        // Balance column dynamically absorbs the remaining available content width
        final double otherColumnsWidth = dateColWidth +
            txnColWidth +
            refColWidth +
            descColWidth +
            statusColWidth +
            billAmtColWidth +
            receivedColWidth +
            overAmtColWidth;
        final double balanceColWidth = math.max(baseBalanceWidth + extraBal, availableContentWidth - otherColumnsWidth);

        // Exact width of all columns combined
        final double totalColumnsWidth = otherColumnsWidth + balanceColWidth;

        // Total scroll width covers columns plus outer margins and inner cell padding
        final double totalScrollWidth = totalColumnsWidth + totalHorizontalOverhead;

        final headerStyle = TextStyle(
          fontSize: isDesktop ? 12 : 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.3,
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalScrollWidth,
            child: Column(
              children: [
                // Table Header Bar
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: isDesktop ? 12 : 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: dateColWidth, child: Text('DATE', style: headerStyle)),
                      SizedBox(width: txnColWidth, child: Text('TXN TYPE', style: headerStyle)),
                      SizedBox(width: refColWidth, child: Text('BILL / REF #', style: headerStyle)),
                      if (_showDescription)
                        SizedBox(width: descColWidth, child: Text('DESCRIPTION', style: headerStyle)),
                      if (_showPaymentStatus)
                        SizedBox(width: statusColWidth, child: Text('STATUS', style: headerStyle)),
                      SizedBox(width: billAmtColWidth, child: Text('BILL AMT (₹)', textAlign: TextAlign.right, style: headerStyle)),
                      SizedBox(width: receivedColWidth, child: Text('RECEIVED (₹)', textAlign: TextAlign.right, style: headerStyle)),
                      SizedBox(width: overAmtColWidth, child: Text('OVER AMT (₹)', textAlign: TextAlign.right, style: headerStyle)),
                      SizedBox(
                        width: balanceColWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('BALANCE (₹)', textAlign: TextAlign.right, style: headerStyle),
                        ),
                      ),
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
                          padding: EdgeInsets.symmetric(horizontal: 13, vertical: isDesktop ? 12 : 10),
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
                                width: dateColWidth,
                                child: Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: isOpening ? FontWeight.w800 : FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                ),
                              ),

                              // 2. Txn Type
                              SizedBox(
                                width: txnColWidth,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                                          fontSize: isDesktop ? 10.5 : 9.5,
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
                                width: refColWidth,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        row.refNo,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 13 : 12,
                                          fontWeight: FontWeight.w700,
                                          color: row.invoice != null ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (row.paymentMode != null && row.paymentMode!.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Text(
                                          row.paymentMode!,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // 4. Description (optional column)
                              if (_showDescription)
                                SizedBox(
                                  width: descColWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text(
                                      row.description.isNotEmpty ? row.description : '-',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 12.5 : 11.5,
                                        color: const Color(0xFF475569),
                                        fontStyle: row.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),

                              // 5. Payment Status (optional column)
                              if (_showPaymentStatus)
                                SizedBox(
                                  width: statusColWidth,
                                  child: _buildStatusBadge(row.paymentStatus),
                                ),

                              // 6. Bill Amount (Debit)
                              SizedBox(
                                width: billAmtColWidth,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    row.billAmount != null
                                        ? CurrencyFormatter.format(row.billAmount!)
                                        : '-',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 13.5 : 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),

                              // 7. Received Amount (Credit)
                              SizedBox(
                                width: receivedColWidth,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    row.receivedAmount != null
                                        ? CurrencyFormatter.format(row.receivedAmount!)
                                        : '-',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 13.5 : 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ),

                              // 8. Over Amount (Excess Paid on this bill)
                              SizedBox(
                                width: overAmtColWidth,
                                child: row.overAmount != null && row.overAmount! > 0
                                    ? Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3E8FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFD8B4FE), width: 0.8),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '+₹${row.overAmount!.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF7C3AED),
                                              ),
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

                              // 9. Running Balance (with Dr/Cr tag)
                              SizedBox(
                                width: balanceColWidth,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      isZeroBalance
                                          ? '₹ 0.00'
                                          : '${CurrencyFormatter.format(row.balance.abs())} ${isPositiveBalance ? "Dr" : "Cr"}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: isDesktop ? 14 : 13,
                                        fontWeight: FontWeight.w900,
                                        color: isPositiveBalance
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF16A34A),
                                      ),
                                    ),
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
      },
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
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
                            Flexible(
                              child: Text(
                                row.refNo,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (row.paymentMode != null && row.paymentMode!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.5),
                              ),
                              child: Text(
                                row.paymentMode!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                          if (_showPaymentStatus && row.paymentStatus != '-') ...[
                            const SizedBox(width: 8),
                            _buildStatusBadge(row.paymentStatus),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (_showDescription && row.description.isNotEmpty && row.description != '-') ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notes_rounded, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row.description,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Amount (Billed / Paid)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPurchase ? 'Bill Amount' : (isPayment ? 'Paid / Received' : 'Starting'),
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
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
                          ),
                        ],
                      ),
                    ),

                    // Over Amount Badge if excess paid
                    if (row.overAmount != null && row.overAmount! > 0) ...[
                      const SizedBox(width: 6),
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
                    ],

                    const SizedBox(width: 8),
                    // Balance after this transaction
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Running Balance', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
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
                          ),
                        ],
                      ),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
  final String description;
  final String paymentStatus;

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
    this.description = '',
    this.paymentStatus = '-',
  });
}

// ─── AppBar Icon Button (Interactive with Hover Effects) ─────────────────────

class _AppBarIconBtn extends StatefulWidget {
  final Color color;
  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _AppBarIconBtn({
    required this.color,
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_AppBarIconBtn> createState() => _AppBarIconBtnState();
}

class _AppBarIconBtnState extends State<_AppBarIconBtn> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isHovered ? widget.color.withValues(alpha: 0.92) : widget.color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onTap,
                splashColor: Colors.white24,
                highlightColor: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 15, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

