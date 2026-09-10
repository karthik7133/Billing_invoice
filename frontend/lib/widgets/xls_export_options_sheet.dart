import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../models/business_model.dart';
import '../services/excel_export_service.dart';
import '../services/share_service.dart';
import 'pdf_progress_dialog.dart';

class XlsExportOptionsSheet extends StatefulWidget {
  final List<InvoiceModel> allInvoices;
  final List<CustomerModel> customers;
  final BusinessModel business;
  final DateTime currentFromDate;
  final DateTime currentToDate;
  final CustomerModel? preselectedParty;

  const XlsExportOptionsSheet({
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
      builder: (ctx) => XlsExportOptionsSheet(
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
  State<XlsExportOptionsSheet> createState() => _XlsExportOptionsSheetState();
}

class _XlsExportOptionsSheetState extends State<XlsExportOptionsSheet> {
  // Scope: 'ALL_TIME', 'PERIOD', 'CUSTOM'
  String _dateScope = 'ALL_TIME';
  late DateTime _customFrom;
  late DateTime _customTo;

  // Party Filter: null = All Parties, or specific customer
  CustomerModel? _selectedParty;

  // Status Filter: 'ALL', 'PAID', 'UNPAID', 'PARTIAL'
  String _statusFilter = 'ALL';

  // Include / Exclude Checkboxes
  bool _includeCompanyHeader = true;
  bool _includeCustomerDetails = true;
  bool _includeTransactionType = true;
  bool _includeItemizedBreakdown = false;
  bool _includeTaxDetails = false;
  bool _includePaymentDetails = true;
  bool _includeOverAmounts = true;
  bool _includeBalances = true;
  bool _includeGrandTotals = true;

  late TextEditingController _fileNameController;

  @override
  void initState() {
    super.initState();
    _selectedParty = widget.preselectedParty;
    _customFrom = widget.currentFromDate;
    _customTo = widget.currentToDate;

    // If invoices exist in period, default to PERIOD, otherwise ALL_TIME
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
          : 'Ledger_${bName.isNotEmpty ? bName : "Business"}_$dateStr',
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  List<InvoiceModel> _getFilteredInvoices() {
    return widget.allInvoices.where((inv) {
      // 1. Date Scope
      if (_dateScope == 'PERIOD') {
        final fromStart = DateTime(widget.currentFromDate.year, widget.currentFromDate.month, widget.currentFromDate.day);
        final toEnd = DateTime(widget.currentToDate.year, widget.currentToDate.month, widget.currentToDate.day, 23, 59, 59);
        if (inv.invoiceDate.isBefore(fromStart) || inv.invoiceDate.isAfter(toEnd)) return false;
      } else if (_dateScope == 'CUSTOM') {
        final fromStart = DateTime(_customFrom.year, _customFrom.month, _customFrom.day);
        final toEnd = DateTime(_customTo.year, _customTo.month, _customTo.day, 23, 59, 59);
        if (inv.invoiceDate.isBefore(fromStart) || inv.invoiceDate.isAfter(toEnd)) return false;
      }

      // 2. Party Scope
      if (_selectedParty != null) {
        if (inv.customerId != _selectedParty!.id && inv.customerSnapshot.id != _selectedParty!.id) {
          return false;
        }
      }

      // 3. Status Scope
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
            primary: Color(0xFF16A34A),
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

  Future<void> _exportAndShare() async {
    final filtered = _getFilteredInvoices();
    final messenger = ScaffoldMessenger.of(context);

    Navigator.pop(context);
    PdfProgressDialog.show(context, message: 'Generating Excel Spreadsheet...');

    try {
      DateTime? from;
      DateTime? to;
      if (_dateScope == 'PERIOD') {
        from = widget.currentFromDate;
        to = widget.currentToDate;
      } else if (_dateScope == 'CUSTOM') {
        from = _customFrom;
        to = _customTo;
      }

      final bytes = await ExcelExportService.generateCustomXlsx(
        invoices: filtered,
        fromDate: from,
        toDate: to,
        business: widget.business,
        specificCustomer: _selectedParty,
        includeCompanyHeader: _includeCompanyHeader,
        includeCustomerDetails: _includeCustomerDetails,
        includeTransactionType: _includeTransactionType,
        includeItemizedBreakdown: _includeItemizedBreakdown,
        includeTaxDetails: _includeTaxDetails,
        includePaymentDetails: _includePaymentDetails,
        includeOverAmounts: _includeOverAmounts,
        includeBalances: _includeBalances,
        includeGrandTotals: _includeGrandTotals,
        reportTitle: _selectedParty != null
            ? 'PARTY ACCOUNT STATEMENT - ${_selectedParty!.name}'
            : 'GENERAL LEDGER & TRANSACTIONS DAYBOOK',
      );

      PdfProgressDialog.hide();
      await Future.delayed(const Duration(milliseconds: 100));

      final rawName = _fileNameController.text.trim();
      final filename = rawName.isEmpty ? 'Billing_Ledger.xlsx' : (rawName.endsWith('.xlsx') ? rawName : '$rawName.xlsx');

      await ShareService.shareXlsFile(
        bytes,
        filename: filename,
        subject: 'Excel Ledger Export - ${widget.business.businessName}',
      );
    } catch (e) {
      PdfProgressDialog.hide();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generating Excel file: $e'),
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
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.table_chart_rounded, color: Color(0xFF16A34A), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Excel (.xlsx) Export Options',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Choose what to include or exclude in your spreadsheet',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── Scrollable Options Body ────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                // 1. Live Record Counter Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: filteredInvoices.isNotEmpty ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: filteredInvoices.isNotEmpty ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        filteredInvoices.isNotEmpty ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: filteredInvoices.isNotEmpty ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          filteredInvoices.isNotEmpty
                              ? '${filteredInvoices.length} Registered Records Ready for Export'
                              : '0 Records Match Current Filter! Tap "All Registered (All Time)" below.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: filteredInvoices.isNotEmpty ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Data / Date Scope Section
                _buildSectionHeader('1. DATA & DATE RANGE SCOPE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildScopeChip(
                      label: 'All Registered (All Time)',
                      subtitle: '(${widget.allInvoices.length} bills)',
                      selected: _dateScope == 'ALL_TIME',
                      onTap: () => setState(() => _dateScope = 'ALL_TIME'),
                    ),
                    _buildScopeChip(
                      label: 'Selected Period',
                      subtitle: '${dfmt.format(widget.currentFromDate)} - ${dfmt.format(widget.currentToDate)}',
                      selected: _dateScope == 'PERIOD',
                      onTap: () => setState(() => _dateScope = 'PERIOD'),
                    ),
                    _buildScopeChip(
                      label: 'Custom Range',
                      subtitle: '${dfmt.format(_customFrom)} - ${dfmt.format(_customTo)}',
                      selected: _dateScope == 'CUSTOM',
                      onTap: _pickCustomRange,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Party & Customer Scope
                _buildSectionHeader('2. PARTY / CUSTOMER FILTER'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
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

                // 5. Include / Exclude Checkboxes
                _buildSectionHeader('4. COLUMNS & DATA TO INCLUDE'),
                const SizedBox(height: 6),
                _buildCheckboxTile(
                  title: 'Company Header & Details',
                  subtitle: 'Business name, GSTIN, phone & address',
                  value: _includeCompanyHeader,
                  onChanged: (v) => setState(() => _includeCompanyHeader = v!),
                ),
                _buildCheckboxTile(
                  title: 'Customer Details',
                  subtitle: 'Customer name, phone & GSTIN columns',
                  value: _includeCustomerDetails,
                  onChanged: (v) => setState(() => _includeCustomerDetails = v!),
                ),
                _buildCheckboxTile(
                  title: 'Transaction Type & Payment Mode',
                  subtitle: 'Sale bill, Cash, UPI, Bank Transfer',
                  value: _includeTransactionType,
                  onChanged: (v) => setState(() => _includeTransactionType = v!),
                ),
                _buildCheckboxTile(
                  title: 'Product / Itemized Breakdown',
                  subtitle: 'Item names, quantity, unit, rate & subtotal lines',
                  value: _includeItemizedBreakdown,
                  accent: true,
                  onChanged: (v) => setState(() => _includeItemizedBreakdown = v!),
                ),
                _buildCheckboxTile(
                  title: 'Tax Amount Column',
                  subtitle: 'Optional single GST tax column',
                  value: _includeTaxDetails,
                  onChanged: (v) => setState(() => _includeTaxDetails = v!),
                ),
                _buildCheckboxTile(
                  title: 'Payments Received (Cr)',
                  subtitle: 'Amount paid & payment receipt columns',
                  value: _includePaymentDetails,
                  onChanged: (v) => setState(() => _includePaymentDetails = v!),
                ),
                _buildCheckboxTile(
                  title: 'Over-Payment Amounts',
                  subtitle: 'Excess advance payments on bills',
                  value: _includeOverAmounts,
                  onChanged: (v) => setState(() => _includeOverAmounts = v!),
                ),
                _buildCheckboxTile(
                  title: 'Balances Due & Status',
                  subtitle: 'Pending balance & bill status tag',
                  value: _includeBalances,
                  onChanged: (v) => setState(() => _includeBalances = v!),
                ),
                _buildCheckboxTile(
                  title: 'Grand Totals & Summary Row',
                  subtitle: 'Calculates bold sums at the bottom of sheet',
                  value: _includeGrandTotals,
                  onChanged: (v) => setState(() => _includeGrandTotals = v!),
                ),

                const SizedBox(height: 18),

                // 6. File Name Customization
                _buildSectionHeader('5. EXCEL FILE NAME'),
                const SizedBox(height: 8),
                TextField(
                  controller: _fileNameController,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    suffixText: '.xlsx',
                    suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                    prefixIcon: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF16A34A)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Sticky Export Button ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: filteredInvoices.isEmpty ? null : _exportAndShare,
                  icon: const Icon(Icons.file_download_rounded, size: 20),
                  label: Text(
                    filteredInvoices.isNotEmpty
                        ? 'Export ${filteredInvoices.length} Records to Excel'
                        : 'No Records Selected',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
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
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildScopeChip({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? const Color(0xFF166534) : const Color(0xFF1E293B),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: selected ? const Color(0xFF15803D) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String code, String label) {
    final selected = _statusFilter == code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _statusFilter = code);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
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
    bool accent = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: accent && value ? const Color(0xFFF0FDF4) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: accent && value ? Border.all(color: const Color(0xFFBBF7D0)) : null,
      ),
      child: CheckboxListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        activeColor: const Color(0xFF16A34A),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent && value ? const Color(0xFF166534) : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
