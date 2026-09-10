import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../models/business_model.dart';
import '../services/pdf_invoice_service.dart';
import '../services/share_service.dart';
import 'pdf_progress_dialog.dart';

class LedgerPdfOptionsSheet extends StatefulWidget {
  final List<InvoiceModel> allInvoices;
  final List<CustomerModel> customers;
  final BusinessModel business;
  final DateTime currentFromDate;
  final DateTime currentToDate;
  final CustomerModel? preselectedParty;

  const LedgerPdfOptionsSheet({
    super.key,
    required this.allInvoices,
    required this.customers,
    required this.business,
    required this.currentFromDate,
    required this.currentToDate,
    this.preselectedParty,
  });

  static Future<void> show(
    BuildContext context, {
    required List<InvoiceModel> allInvoices,
    required List<CustomerModel> customers,
    required BusinessModel business,
    required DateTime currentFromDate,
    required DateTime currentToDate,
    CustomerModel? preselectedParty,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LedgerPdfOptionsSheet(
        allInvoices: allInvoices,
        customers: customers,
        business: business,
        currentFromDate: currentFromDate,
        currentToDate: currentToDate,
        preselectedParty: preselectedParty,
      ),
    );
  }

  @override
  State<LedgerPdfOptionsSheet> createState() => _LedgerPdfOptionsSheetState();
}

class _LedgerPdfOptionsSheetState extends State<LedgerPdfOptionsSheet> {
  String _dateScope = 'PERIOD';
  late DateTime _customFrom;
  late DateTime _customTo;

  CustomerModel? _selectedParty;
  String _statusFilter = 'ALL';

  // Toggleable columns & options
  bool _showItemDetails = true;
  bool _showPaymentInfo = true;
  bool _showBalance = true;
  bool _showPaymentStatus = true;
  bool _showGrandTotals = true;

  late TextEditingController _fileNameController;

  @override
  void initState() {
    super.initState();
    _selectedParty = widget.preselectedParty;
    _customFrom = widget.currentFromDate;
    _customTo = widget.currentToDate;

    final periodInvoices = widget.allInvoices.where((inv) {
      final fromStart = DateTime(widget.currentFromDate.year, widget.currentFromDate.month, widget.currentFromDate.day);
      final toEnd = DateTime(widget.currentToDate.year, widget.currentToDate.month, widget.currentToDate.day, 23, 59, 59);
      return !inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd);
    }).toList();

    _dateScope = periodInvoices.isNotEmpty ? 'PERIOD' : 'ALL_TIME';

    final bName = widget.business.businessName.replaceAll(' ', '_');
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _fileNameController = TextEditingController(
      text: _selectedParty != null
          ? 'Statement_${_selectedParty!.name.replaceAll(' ', '_')}_$dateStr'
          : 'Ledger_${bName.isNotEmpty ? bName : "Daybook"}_$dateStr',
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  List<InvoiceModel> _getFilteredInvoices() {
    return widget.allInvoices.where((inv) {
      // 1. Date Filter
      if (_dateScope == 'PERIOD') {
        final fromStart = DateTime(widget.currentFromDate.year, widget.currentFromDate.month, widget.currentFromDate.day);
        final toEnd = DateTime(widget.currentToDate.year, widget.currentToDate.month, widget.currentToDate.day, 23, 59, 59);
        if (inv.invoiceDate.isBefore(fromStart) || inv.invoiceDate.isAfter(toEnd)) return false;
      } else if (_dateScope == 'CUSTOM') {
        final fromStart = DateTime(_customFrom.year, _customFrom.month, _customFrom.day);
        final toEnd = DateTime(_customTo.year, _customTo.month, _customTo.day, 23, 59, 59);
        if (inv.invoiceDate.isBefore(fromStart) || inv.invoiceDate.isAfter(toEnd)) return false;
      }

      // 2. Party Filter
      if (_selectedParty != null) {
        if (inv.customerId != _selectedParty!.id && inv.customerSnapshot.id != _selectedParty!.id) {
          return false;
        }
      }

      // 3. Status Filter
      if (_statusFilter == 'PAID' && inv.status != 'PAID') return false;
      if (_statusFilter == 'UNPAID' && (inv.balanceDue <= 0 || inv.status == 'PAID')) return false;
      if (_statusFilter == 'PARTIAL' && (inv.status != 'PARTIALLY_PAID' || inv.amountPaid <= 0)) return false;

      return true;
    }).toList();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _customFrom, end: _customTo),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFDC2626),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customFrom = picked.start;
        _customTo = picked.end;
        _dateScope = 'CUSTOM';
      });
    }
  }

  Future<void> _generateAndSharePdf() async {
    final filtered = _getFilteredInvoices();
    final messenger = ScaffoldMessenger.of(context);

    Navigator.pop(context);
    PdfProgressDialog.show(context, message: 'Generating PDF Statement...');

    try {
      DateTime fromDate;
      DateTime toDate;
      if (_dateScope == 'PERIOD') {
        fromDate = widget.currentFromDate;
        toDate = widget.currentToDate;
      } else if (_dateScope == 'CUSTOM') {
        fromDate = _customFrom;
        toDate = _customTo;
      } else {
        // All Time
        if (filtered.isNotEmpty) {
          final sorted = List<InvoiceModel>.from(filtered)..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));
          fromDate = sorted.first.invoiceDate;
          toDate = sorted.last.invoiceDate;
        } else {
          fromDate = widget.currentFromDate;
          toDate = widget.currentToDate;
        }
      }

      final bytes = await PdfInvoiceService.generateGeneralLedgerPdf(
        invoices: filtered,
        fromDate: fromDate,
        toDate: toDate,
        business: widget.business,
        specificCustomer: _selectedParty,
        showItemDetails: _showItemDetails,
        showPaymentInfo: _showPaymentInfo,
        showBalance: _showBalance,
        showPaymentStatus: _showPaymentStatus,
        showGrandTotals: _showGrandTotals,
        reportTitle: _selectedParty != null
            ? 'PARTY ACCOUNT STATEMENT - ${_selectedParty!.name.toUpperCase()}'
            : 'GENERAL LEDGER & TRANSACTIONS DAYBOOK',
      );

      PdfProgressDialog.hide();
      await Future.delayed(const Duration(milliseconds: 100));

      final rawName = _fileNameController.text.trim();
      final filename = rawName.isEmpty
          ? 'Ledger_Statement.pdf'
          : (rawName.endsWith('.pdf') ? rawName : '$rawName.pdf');

      await ShareService.sharePdf(
        bytes,
        filename: filename,
      );
    } catch (e) {
      PdfProgressDialog.hide();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _getFilteredInvoices();
    final dfmt = DateFormat('dd/MM/yyyy');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ─── Sheet Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Export PDF Statement',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'A4 formatted with company header & clean columns',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── Scrollable Options Body ─────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                // 1. Live Record Counter Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: filteredInvoices.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: filteredInvoices.isNotEmpty ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filteredInvoices.isNotEmpty ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                        size: 18,
                        color: filteredInvoices.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${filteredInvoices.length} transactions match your selection',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: filteredInvoices.isNotEmpty ? const Color(0xFF991B1B) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Date Scope
                _buildSectionHeader('1. SELECT DATE RANGE'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildScopeOption(
                      title: 'Current Period',
                      subtitle: '${dfmt.format(widget.currentFromDate)} - ${dfmt.format(widget.currentToDate)}',
                      selected: _dateScope == 'PERIOD',
                      onTap: () => setState(() => _dateScope = 'PERIOD'),
                    ),
                    const SizedBox(width: 8),
                    _buildScopeOption(
                      title: 'All Time',
                      subtitle: 'All records',
                      selected: _dateScope == 'ALL_TIME',
                      onTap: () => setState(() => _dateScope = 'ALL_TIME'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickCustomRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _dateScope == 'CUSTOM' ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _dateScope == 'CUSTOM' ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                        width: _dateScope == 'CUSTOM' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFFDC2626)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _dateScope == 'CUSTOM'
                                ? 'Custom: ${dfmt.format(_customFrom)} to ${dfmt.format(_customTo)}'
                                : 'Choose Custom Date Range...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _dateScope == 'CUSTOM' ? FontWeight.w700 : FontWeight.w500,
                              color: _dateScope == 'CUSTOM' ? const Color(0xFF991B1B) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Party Filter
                _buildSectionHeader('2. PARTY / CUSTOMER FILTER'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedParty?.id ?? 'ALL',
                      items: [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text(
                            'All Customers / Parties (${widget.customers.length} Parties)',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                        ),
                        ...widget.customers.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                '${c.name} ${c.phone.isNotEmpty ? "(${c.phone})" : ""}',
                                style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          if (val == null || val == 'ALL') {
                            _selectedParty = null;
                          } else {
                            _selectedParty = widget.customers.firstWhere((c) => c.id == val);
                          }
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Status Filter
                _buildSectionHeader('3. TRANSACTION STATUS'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusChip('ALL', 'All'),
                    const SizedBox(width: 6),
                    _buildStatusChip('PAID', 'Paid Only'),
                    const SizedBox(width: 6),
                    _buildStatusChip('UNPAID', 'Pending Dues'),
                    const SizedBox(width: 6),
                    _buildStatusChip('PARTIAL', 'Partial'),
                  ],
                ),

                const SizedBox(height: 18),

                // 5. Data & Columns to Include
                _buildSectionHeader('4. COLUMNS & DATA TO INCLUDE'),
                const SizedBox(height: 6),
                _buildCheckboxTile(
                  title: 'Item Details & Merged Qty',
                  subtitle: 'Item names and quantities with units, e.g. Crab (5 kg)',
                  value: _showItemDetails,
                  onChanged: (v) => setState(() => _showItemDetails = v!),
                ),
                _buildCheckboxTile(
                  title: 'Payments Received (Cr ₹)',
                  subtitle: 'Amount paid and credit column',
                  value: _showPaymentInfo,
                  onChanged: (v) => setState(() => _showPaymentInfo = v!),
                ),
                _buildCheckboxTile(
                  title: 'Balance Due Column (₹)',
                  subtitle: 'Remaining balance due per transaction',
                  value: _showBalance,
                  onChanged: (v) => setState(() => _showBalance = v!),
                ),
                _buildCheckboxTile(
                  title: 'Payment Status Badge',
                  subtitle: 'PAID, DUE, or PARTIAL tag',
                  value: _showPaymentStatus,
                  onChanged: (v) => setState(() => _showPaymentStatus = v!),
                ),
                _buildCheckboxTile(
                  title: 'Grand Totals Summary Box',
                  subtitle: 'Totals for Billed, Received & Outstanding dues',
                  value: _showGrandTotals,
                  onChanged: (v) => setState(() => _showGrandTotals = v!),
                ),

                const SizedBox(height: 18),

                // 6. PDF File Name
                _buildSectionHeader('5. PDF FILE NAME'),
                const SizedBox(height: 8),
                TextField(
                  controller: _fileNameController,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    suffixText: '.pdf',
                    suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    prefixIcon: const Icon(Icons.description_outlined, size: 18, color: Color(0xFFDC2626)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ─── Footer Action Button ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: Text(
                      'Generate & Share PDF (${filteredInvoices.length} Bills)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    onPressed: filteredInvoices.isEmpty ? null : _generateAndSharePdf,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF64748B),
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildScopeOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String statusKey, String label) {
    final selected = _statusFilter == statusKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = statusKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
