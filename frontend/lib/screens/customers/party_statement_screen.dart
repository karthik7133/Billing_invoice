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
    return '${name}_$date';
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

  List<InvoiceModel> _getFilteredInvoices(List<InvoiceModel> all) {
    return all.where((inv) {
      final d = inv.invoiceDate;
      final fromDay = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final toDay = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
      return !d.isBefore(fromDay) && !d.isAfter(toDay);
    }).toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
  }

  /// Build running balance rows (like a ledger)
  List<_StatementRow> _buildRows(List<InvoiceModel> invoices) {
    final rows = <_StatementRow>[];
    double balance = 0.0;

    // Opening balance row
    rows.add(_StatementRow(
      type: 'Receivable Begi...',
      date: _fromDate,
      subLabel: '',
      amount: null,
      balance: 0.0,
      isOpening: true,
    ));

    for (final inv in invoices) {
      balance += inv.grandTotal;
      rows.add(_StatementRow(
        type: 'Purchase',
        date: inv.invoiceDate,
        subLabel: 'Purchase ${inv.invoiceNumber}',
        amount: inv.grandTotal,
        balance: balance,
      ));

      if (inv.amountPaid > 0) {
        balance -= inv.amountPaid;
        rows.add(_StatementRow(
          type: 'Payment',
          date: inv.invoiceDate,
          subLabel: 'Payment received',
          amount: -inv.amountPaid,
          balance: balance,
        ));
      }
    }

    return rows;
  }

  // ─── PDF Click → directly to "What to display on PDF?" ───────────────────

  void _showPdfOptionsSheet(List<InvoiceModel> invoices) {
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final defaultFileName = _pdfFileName.isNotEmpty
        ? _pdfFileName
        : _buildDefaultFileName();

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

  void _shareAsXls(List<InvoiceModel> invoices) {
    HapticFeedback.lightImpact();
    // Build CSV-style text for XLS sharing
    final buf = StringBuffer();
    buf.writeln('Party Statement - ${widget.customer.name}');
    buf.writeln('Period: ${DateFormat('dd/MM/yyyy').format(_fromDate)} to ${DateFormat('dd/MM/yyyy').format(_toDate)}');
    buf.writeln('');
    buf.writeln('Date,Type,Invoice No.,Amount,Balance');

    double balance = 0.0;
    for (final inv in invoices) {
      balance += inv.grandTotal;
      buf.writeln(
        '${DateFormat('dd/MM/yyyy').format(inv.invoiceDate)},Purchase,${inv.invoiceNumber},${inv.grandTotal.toStringAsFixed(2)},${balance.toStringAsFixed(2)}',
      );
      if (inv.amountPaid > 0) {
        balance -= inv.amountPaid;
        buf.writeln(
          '${DateFormat('dd/MM/yyyy').format(inv.invoiceDate)},Payment,,-${inv.amountPaid.toStringAsFixed(2)},${balance.toStringAsFixed(2)}',
        );
      }
    }
    buf.writeln('');
    buf.writeln('Closing Balance,,,${balance.toStringAsFixed(2)}');

    ShareService.shareText(
      text: buf.toString(),
      subject: 'Party Statement - ${widget.customer.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final allParty = invoiceProvider.getInvoicesForCustomer(widget.customer.id);
    final filtered = _getFilteredInvoices(allParty);
    final rows = _buildRows(filtered);
    final closingBalance = filtered.fold<double>(0.0, (s, inv) => s + inv.balanceDue);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Party Statement',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        actions: [
          // PDF icon
          _AppBarIconBtn(
            color: const Color(0xFFDC2626),
            label: 'PDF',
            onTap: () => _showPdfOptionsSheet(filtered),
          ),
          const SizedBox(width: 6),
          // XLS icon
          _AppBarIconBtn(
            color: const Color(0xFF16A34A),
            label: 'XLS',
            onTap: () => _shareAsXls(filtered),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // ─── Date Range Row ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Range dropdown
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
                // Calendar icon
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                // From date
                GestureDetector(
                  onTap: () => _pickDate(isFrom: true),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_fromDate),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('TO', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                ),
                // To date
                GestureDetector(
                  onTap: () => _pickDate(isFrom: false),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_toDate),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),

          // ─── Filters Row ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filters Applied:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF2563EB)),
                  label: const Text('Filters', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

          // Theme chip
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: const Text('Theme - Vyapar View', style: TextStyle(fontSize: 11, color: Color(0xFF1E293B))),
                  backgroundColor: const Color(0xFFF1F5F9),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
          ),

          // ─── Customer Search Bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.customer.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ),
                  const Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                ],
              ),
            ),
          ),

          // ─── Closing Balance Card ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Closing balance', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(closingBalance),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ),

          // ─── Table Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('Txns Type', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Balance', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))),
              ],
            ),
          ),

          // ─── Transaction List ────────────────────────────────────────────
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
                          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Adjust the date range to see transactions',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 1),
                    itemBuilder: (ctx, i) => _buildStatementRow(rows[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementRow(_StatementRow row) {
    final dateStr = DateFormat('dd MMM, yy').format(row.date).toUpperCase();
    final isOpening = row.isOpening;
    final isPayment = row.type == 'Payment';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + date
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.type,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOpening ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.subLabel.isNotEmpty ? '$dateStr · ${row.subLabel}' : dateStr,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          // Amount
          Expanded(
            flex: 3,
            child: Text(
              row.amount != null
                  ? '₹${row.amount!.abs().toStringAsFixed(2)}'
                  : '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPayment ? AppColors.receivableGreen : const Color(0xFF1E293B),
              ),
            ),
          ),
          // Balance
          Expanded(
            flex: 3,
            child: Text(
              isOpening
                  ? '₹ 0.00'
                  : '₹${row.balance.abs().toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isOpening
                    ? AppColors.receivableGreen
                    : (row.balance <= 0 ? AppColors.receivableGreen : const Color(0xFFDC2626)),
              ),
            ),
          ),
        ],
      ),
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

// ─── Data Model ───────────────────────────────────────────────────────────────

class _StatementRow {
  final String type;
  final DateTime date;
  final String subLabel;
  final double? amount;
  final double balance;
  final bool isOpening;

  _StatementRow({
    required this.type,
    required this.date,
    required this.subLabel,
    required this.amount,
    required this.balance,
    this.isOpening = false,
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
