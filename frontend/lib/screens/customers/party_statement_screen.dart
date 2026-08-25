import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../services/pdf_invoice_service.dart';
import '../../services/share_service.dart';

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

  // ─── PDF Options Sheet ─────────────────────────────────────────────────────

  void _showPdfOptionsSheet(List<InvoiceModel> invoices) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PdfOptionsSheet(
        customer: widget.customer,
        invoices: invoices,
        fromDate: _fromDate,
        toDate: _toDate,
        onSharePdf: () {
          Navigator.pop(ctx);
          _showPdfDisplayOptionsSheet(invoices);
        },
      ),
    );
  }

  void _showPdfDisplayOptionsSheet(List<InvoiceModel> invoices) {
    final fileNameController = TextEditingController(text: _pdfFileName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _PdfDisplayOptionsSheet(
          fileName: fileNameController.text,
          fileNameController: fileNameController,
          showItemDetails: _showItemDetails,
          showDescription: _showDescription,
          showPaymentStatus: _showPaymentStatus,
          showPaymentInfo: _showPaymentInfo,
          onToggle: (field, val) {
            setSheetState(() {
              switch (field) {
                case 'itemDetails':
                  _showItemDetails = val;
                  break;
                case 'description':
                  _showDescription = val;
                  break;
                case 'paymentStatus':
                  _showPaymentStatus = val;
                  break;
                case 'paymentInfo':
                  _showPaymentInfo = val;
                  break;
              }
            });
            setState(() {});
          },
          onApply: () async {
            setState(() => _pdfFileName = fileNameController.text.trim());
            Navigator.pop(ctx);
            // Generate and share PDF
            try {
              final bytes = await PdfInvoiceService.generatePartyStatementPdf(
                customer: widget.customer,
                invoices: invoices,
                fromDate: _fromDate,
                toDate: _toDate,
                showItemDetails: _showItemDetails,
                showDescription: _showDescription,
                showPaymentStatus: _showPaymentStatus,
                showPaymentInfo: _showPaymentInfo,
              );
              final filename = '${_pdfFileName.isNotEmpty ? _pdfFileName : _buildDefaultFileName()}.pdf';
              await ShareService.sharePdf(bytes, filename: filename);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error generating PDF: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
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

// ─── PDF Options Sheet ────────────────────────────────────────────────────────

class _PdfOptionsSheet extends StatelessWidget {
  final CustomerModel customer;
  final List<InvoiceModel> invoices;
  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onSharePdf;

  const _PdfOptionsSheet({
    required this.customer,
    required this.invoices,
    required this.fromDate,
    required this.toDate,
    required this.onSharePdf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PDF Options',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _PdfOption(
              icon: Icons.open_in_new_rounded,
              label: 'Open PDF',
              onTap: () async {
                Navigator.pop(context);
                try {
                  final bytes = await PdfInvoiceService.generatePartyStatementPdf(
                    customer: customer,
                    invoices: invoices,
                    fromDate: fromDate,
                    toDate: toDate,
                  );
                  await ShareService.sharePdf(bytes, filename: 'statement.pdf');
                } catch (_) {}
              },
            ),
            _PdfOption(
              icon: Icons.print_outlined,
              label: 'Print PDF',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Print feature coming soon'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
            _PdfOption(
              icon: Icons.share_outlined,
              label: 'Share PDF',
              onTap: onSharePdf,
            ),
            _PdfOption(
              icon: Icons.download_outlined,
              label: 'Save PDF to Phone',
              onTap: () async {
                Navigator.pop(context);
                try {
                  final bytes = await PdfInvoiceService.generatePartyStatementPdf(
                    customer: customer,
                    invoices: invoices,
                    fromDate: fromDate,
                    toDate: toDate,
                  );
                  await ShareService.sharePdf(bytes, filename: '${customer.name}_statement.pdf');
                } catch (_) {}
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PdfOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PdfOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF374151), size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    );
  }
}

// ─── PDF Display Options Sheet ────────────────────────────────────────────────

class _PdfDisplayOptionsSheet extends StatefulWidget {
  final String fileName;
  final TextEditingController fileNameController;
  final bool showItemDetails;
  final bool showDescription;
  final bool showPaymentStatus;
  final bool showPaymentInfo;
  final void Function(String field, bool val) onToggle;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  const _PdfDisplayOptionsSheet({
    required this.fileName,
    required this.fileNameController,
    required this.showItemDetails,
    required this.showDescription,
    required this.showPaymentStatus,
    required this.showPaymentInfo,
    required this.onToggle,
    required this.onApply,
    required this.onCancel,
  });

  @override
  State<_PdfDisplayOptionsSheet> createState() => _PdfDisplayOptionsSheetState();
}

class _PdfDisplayOptionsSheetState extends State<_PdfDisplayOptionsSheet> {
  late bool _showItemDetails;
  late bool _showDescription;
  late bool _showPaymentStatus;
  late bool _showPaymentInfo;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _showItemDetails = widget.showItemDetails;
    _showDescription = widget.showDescription;
    _showPaymentStatus = widget.showPaymentStatus;
    _showPaymentInfo = widget.showPaymentInfo;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'What to display on PDF?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filename row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _editingName
                          ? TextField(
                              controller: widget.fileNameController,
                              autofocus: true,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => setState(() => _editingName = false),
                            )
                          : Text(
                              widget.fileNameController.text,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _editingName = !_editingName),
                      child: Text(
                        _editingName ? 'Done' : 'Edit Name',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Checkboxes
              _DisplayOption(
                label: 'Item Details',
                value: _showItemDetails,
                onChanged: (v) {
                  setState(() => _showItemDetails = v);
                  widget.onToggle('itemDetails', v);
                },
              ),
              _DisplayOption(
                label: 'Description',
                value: _showDescription,
                onChanged: (v) {
                  setState(() => _showDescription = v);
                  widget.onToggle('description', v);
                },
              ),
              _DisplayOption(
                label: 'Payment status',
                value: _showPaymentStatus,
                onChanged: (v) {
                  setState(() => _showPaymentStatus = v);
                  widget.onToggle('paymentStatus', v);
                },
              ),
              _DisplayOption(
                label: 'Payment Information',
                value: _showPaymentInfo,
                onChanged: (v) {
                  setState(() => _showPaymentInfo = v);
                  widget.onToggle('paymentInfo', v);
                },
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisplayOption extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DisplayOption({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }
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
