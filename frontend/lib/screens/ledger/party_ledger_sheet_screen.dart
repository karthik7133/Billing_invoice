import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/customer_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/excel_export_service.dart';
import '../../services/share_service.dart';
import '../../core/constants/app_colors.dart';

class PartyLedgerSheetScreen extends StatefulWidget {
  final CustomerModel party;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;

  const PartyLedgerSheetScreen({
    super.key,
    required this.party,
    this.initialFromDate,
    this.initialToDate,
  });

  @override
  State<PartyLedgerSheetScreen> createState() => _PartyLedgerSheetScreenState();
}

class _PartyLedgerSheetScreenState extends State<PartyLedgerSheetScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;
  final List<LedgerRowItem> _rows = [];
  bool _isExporting = false;

  final DateFormat _dfmt = DateFormat('dd/MM/yy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = widget.initialFromDate ?? DateTime(now.year, now.month, 1);
    _toDate = widget.initialToDate ?? DateTime(now.year, now.month + 1, 0);
    _buildRowsFromInvoices();
  }

  /// Populate rows from the party's invoices and multiple payments
  void _buildRowsFromInvoices() {
    final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final business = Provider.of<BusinessProvider>(context, listen: false).business;

    final fromStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toEnd = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    final invoices = invProvider
        .getInvoicesForCustomer(widget.party.id)
        .where((inv) =>
            !inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd))
        .toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    final bShort = business.businessName.isNotEmpty
        ? business.businessName.split(' ').first.toUpperCase()
        : 'JMJ';
    final pName = widget.party.name.toUpperCase();

    _rows.clear();

    double runningDebit = 0;
    double runningCredit = 0;

    for (final inv in invoices) {
      // 1. Debit Row: Bill
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

      runningDebit += inv.grandTotal;
      _rows.add(LedgerRowItem(
        id: 'bill_${inv.id}',
        date: inv.invoiceDate,
        description: billDesc,
        debit: inv.grandTotal,
        invoiceId: inv.id,
      ));

      // 2. Credit Rows: Payments
      if (inv.payments.isNotEmpty) {
        for (int i = 0; i < inv.payments.length; i++) {
          final p = inv.payments[i];
          runningCredit += p.amount;
          final payMode = p.type.isNotEmpty ? p.type.toUpperCase() : 'CASH';
          final payDesc = p.notes.isNotEmpty
              ? p.notes.toUpperCase()
              : '$bShort TO $pName $payMode PAID';

          _rows.add(LedgerRowItem(
            id: 'pay_${inv.id}_$i',
            date: p.date,
            description: payDesc,
            credit: p.amount,
            invoiceId: inv.id,
            paymentId: p.id,
          ));
        }
      } else if (inv.amountPaid > 0) {
        runningCredit += inv.amountPaid;
        final payMode = inv.paymentType.isNotEmpty ? inv.paymentType.toUpperCase() : 'CASH';
        final payDesc = '$bShort TO $pName $payMode PAID';

        _rows.add(LedgerRowItem(
          id: 'pay_${inv.id}_single',
          date: inv.invoiceDate,
          description: payDesc,
          credit: inv.amountPaid,
          invoiceId: inv.id,
        ));
      }

      // 3. Settlement block if fully settled
      if (inv.amountPaid > 0 && inv.balanceDue <= 0) {
        _rows.add(LedgerRowItem(
          id: 'settle_tot_${inv.id}',
          date: inv.invoiceDate,
          description: '',
          credit: inv.amountPaid,
          debit: inv.grandTotal,
          isSettlementTotal: true,
          invoiceId: inv.id,
        ));

        _rows.add(LedgerRowItem(
          id: 'settle_ban_${inv.id}',
          date: inv.invoiceDate,
          description: 'SETTLEMENT',
          isSettlementBanner: true,
          invoiceId: inv.id,
        ));
      }
    }

    // If multiple bills or remaining dues exist, append a summary row
    if (invoices.length > 1) {
      _rows.add(LedgerRowItem(
        id: 'final_total',
        date: _toDate,
        description: 'TOTAL',
        credit: runningCredit,
        debit: runningDebit,
        isSettlementTotal: true,
      ));

      if (runningDebit > runningCredit) {
        _rows.add(LedgerRowItem(
          id: 'final_balance',
          date: _toDate,
          description: 'BALANCE DUE',
          debit: runningDebit - runningCredit,
          isSettlementTotal: true,
        ));
      }
    }
  }

  String _formatAmt(double? amt) {
    if (amt == null) return '';
    if (amt == amt.roundToDouble()) {
      return '${amt.toInt()}/-';
    }
    return '${amt.toStringAsFixed(2)}/-';
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
        _buildRowsFromInvoices();
      });
    }
  }

  void _showEditRowDialog(int index) {
    final row = _rows[index];
    if (row.isSettlementBanner) return; // Banner is visual

    DateTime pickedDate = row.date;
    final descCtrl = TextEditingController(text: row.description);
    final amtCtrl = TextEditingController(
      text: row.isPayment
          ? (row.credit?.toString() ?? '')
          : (row.debit?.toString() ?? ''),
    );
    bool isCredit = row.isPayment;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        row.isSettlementTotal ? 'Edit Summary Row' : 'Edit Ledger Row',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Entry Type Toggle (Credit / Debit)
                  if (!row.isSettlementTotal) ...[
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => isCredit = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isCredit ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCredit ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                  width: isCredit ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Credit (Payment Received)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCredit ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => isCredit = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isCredit ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !isCredit ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                  width: !isCredit ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Debit (Bill / Sale)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: !isCredit ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Date Picker Row
                  Row(
                    children: [
                      const Text('Date: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined, size: 14),
                        label: Text(_dfmt.format(pickedDate)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: modalCtx,
                            initialDate: pickedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (d != null) {
                            setModalState(() => pickedDate = d);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                        onPressed: () {
                          setState(() {
                            _rows.removeAt(index);
                          });
                          Navigator.pop(modalCtx);
                        },
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                        onPressed: () {
                          final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                          setState(() {
                            row.date = pickedDate;
                            row.description = descCtrl.text.trim().toUpperCase();
                            if (isCredit) {
                              row.credit = amt;
                              row.debit = null;
                            } else {
                              row.debit = amt;
                              row.credit = null;
                            }
                          });
                          Navigator.pop(modalCtx);
                        },
                        child: const Text('Update Row', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddEntryDialog({bool defaultCredit = true}) {
    DateTime pickedDate = DateTime.now();
    final descCtrl = TextEditingController(
      text: defaultCredit ? 'JMJ TO ${widget.party.name.toUpperCase()} CASH PAID' : 'PUR + EXP',
    );
    final amtCtrl = TextEditingController();
    bool isCredit = defaultCredit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Ledger Row',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Entry Type Toggle
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() {
                            isCredit = true;
                            descCtrl.text = 'JMJ TO ${widget.party.name.toUpperCase()} CASH PAID';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isCredit ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCredit ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                width: isCredit ? 1.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Credit (Payment Received)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isCredit ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() {
                            isCredit = false;
                            descCtrl.text = 'PUR + EXP';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isCredit ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: !isCredit ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                width: !isCredit ? 1.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Debit (Bill / Sale)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: !isCredit ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Date Picker Row
                  Row(
                    children: [
                      const Text('Date: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_outlined, size: 14),
                        label: Text(_dfmt.format(pickedDate)),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: modalCtx,
                            initialDate: pickedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (d != null) {
                            setModalState(() => pickedDate = d);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                        onPressed: () {
                          final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                          if (amt <= 0) return;

                          setState(() {
                            _rows.add(LedgerRowItem(
                              id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                              date: pickedDate,
                              description: descCtrl.text.trim().toUpperCase(),
                              credit: isCredit ? amt : null,
                              debit: !isCredit ? amt : null,
                            ));
                          });
                          Navigator.pop(modalCtx);
                        },
                        child: const Text('Add Row', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await ExcelExportService.generateFromLedgerRowsXlsx(rows: _rows);

      final cleanName = widget.party.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final dateTag = DateFormat('ddMMMyyyy').format(DateTime.now());
      final filename = 'Ledger_${cleanName}_$dateTag.xlsx';

      final opened = await ShareService.openXlsFile(
        bytes,
        filename: filename,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opened
                        ? 'Excel opened: $filename'
                        : 'Excel saved: $filename',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.party.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            Text(
              '${_dfmt.format(_fromDate)} - ${_dfmt.format(_toDate)} • Interactive Sheet',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined, color: Color(0xFF2563EB)),
            tooltip: 'Filter Date Range',
            onPressed: _pickDateRange,
          ),
          _isExporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.file_download_outlined, color: Color(0xFF059669)),
                  tooltip: 'Export Excel (.xlsx)',
                  onPressed: _exportExcel,
                ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Color(0xFF64748B)),
            tooltip: 'Reset to Invoices',
            onPressed: () {
              setState(() => _buildRowsFromInvoices());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sheet refreshed from saved transactions')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFEFF6FF),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Exact ex.xlsx format. Tap any row to edit date, description, or amount.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                ),
                TextButton(
                  onPressed: () => _showAddEntryDialog(defaultCredit: true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('+ Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                ),
              ],
            ),
          ),

          // Horizontally Scrollable Spreadsheet Table
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const minTableWidth = 520.0;
                final tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        // Spreadsheet Header Table
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 85,
                                child: Text(
                                  'DATE',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'DESCRIPTION',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'CREDIT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'DEBIT',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black54),

                        // Spreadsheet Rows
                        Expanded(
                          child: _rows.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No transactions in this period',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  itemCount: _rows.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  itemBuilder: (ctx, i) {
                                    final r = _rows[i];

                                    // 1. Settlement Banner
                                    if (r.isSettlementBanner) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        color: const Color(0xFFE2E8F0),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'SETTLEMENT',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      );
                                    }

                                    // 2. Settlement / Summary Totals Row
                                    if (r.isSettlementTotal) {
                                      return InkWell(
                                        onTap: () => _showEditRowDialog(i),
                                        child: Container(
                                          color: const Color(0xFFF8FAFC),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 85),
                                              Expanded(
                                                child: Text(
                                                  r.description,
                                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.black),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 110,
                                                child: Text(
                                                  _formatAmt(r.credit),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFFDC2626), // Red credit total
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 110,
                                                child: Text(
                                                  _formatAmt(r.debit),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF1D4ED8), // Blue debit total
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    // 3. Normal Row (Bill Debit in Blue, Payment Credit in Red)
                                    final isPayment = r.isPayment;
                                    final rowColor = isPayment ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8);

                                    return InkWell(
                                      onTap: () => _showEditRowDialog(i),
                                      child: Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Date
                                            SizedBox(
                                              width: 85,
                                              child: Text(
                                                _dfmt.format(r.date),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: rowColor,
                                                ),
                                              ),
                                            ),
                                            // Description
                                            Expanded(
                                              child: Text(
                                                r.description,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: rowColor,
                                                ),
                                              ),
                                            ),
                                            // Credit (Red)
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                isPayment ? _formatAmt(r.credit) : '',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFFDC2626),
                                                ),
                                              ),
                                            ),
                                            // Debit (Blue)
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                !isPayment ? _formatAmt(r.debit) : '',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1D4ED8),
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
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAddEntryDialog(defaultCredit: true),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('+ Payment (Credit)', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showAddEntryDialog(defaultCredit: false),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('+ Bill (Debit)', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportExcel,
                  icon: const Icon(Icons.file_download, size: 16, color: Colors.white),
                  label: const Text('Export XLS', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
