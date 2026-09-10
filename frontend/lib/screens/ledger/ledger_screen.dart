import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/excel_export_service.dart';
import '../../services/share_service.dart';
import '../../widgets/party_xls_save_sheet.dart';

class LedgerScreen extends StatefulWidget {
  final CustomerModel? initialParty;

  const LedgerScreen({super.key, this.initialParty});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _selectedRange = 'This Month';
  late DateTime _fromDate;
  late DateTime _toDate;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Which party XLS is being generated right now
  String? _loadingPartyId;

  final List<String> _rangeOptions = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'Last Month',
    'This Quarter',
    'This FY',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _applyDateRange('This Month');
    if (widget.initialParty != null) {
      _searchController.text = widget.initialParty!.name;
      _searchQuery = widget.initialParty!.name;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyDateRange(String range) {
    final now = DateTime.now();
    setState(() {
      _selectedRange = range;
      switch (range) {
        case 'Today':
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Yesterday':
          final y = now.subtract(const Duration(days: 1));
          _fromDate = DateTime(y.year, y.month, y.day);
          _toDate = DateTime(y.year, y.month, y.day);
          break;
        case 'This Week':
          final start = now.subtract(Duration(days: now.weekday - 1));
          _fromDate = DateTime(start.year, start.month, start.day);
          _toDate = DateTime(now.year, now.month, now.day);
          break;
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
        case 'This FY':
          final fyYear = now.month >= 4 ? now.year : now.year - 1;
          _fromDate = DateTime(fyYear, 4, 1);
          _toDate = DateTime(fyYear + 1, 3, 31);
          break;
        default:
          break;
      }
    });
  }

  void _navigatePeriod(bool forward) {
    HapticFeedback.selectionClick();
    setState(() {
      final newMonth = forward ? _fromDate.month + 1 : _fromDate.month - 1;
      final year = _fromDate.year + (newMonth > 12 ? 1 : (newMonth < 1 ? -1 : 0));
      final m = newMonth > 12 ? 1 : (newMonth < 1 ? 12 : newMonth);
      _fromDate = DateTime(year, m, 1);
      _toDate = DateTime(year, m + 1, 0);
      _selectedRange = 'Custom';
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
        _selectedRange = 'Custom';
      });
    }
  }

  /// Generate and open party XLS directly in Excel / WPS / supported office app
  Future<void> _openPartyXls(
    CustomerModel party,
    List<InvoiceModel> allInvoices,
    BusinessModel business,
  ) async {
    HapticFeedback.lightImpact();
    setState(() => _loadingPartyId = party.id);

    try {
      final bytes = await ExcelExportService.generatePartyLedgerXlsx(
        customer: party,
        allInvoices: allInvoices,
        fromDate: _fromDate,
        toDate: _toDate,
        business: business,
      );

      final safeName = party.name.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
      final fromStr = DateFormat('dd-MM-yy').format(_fromDate);
      final toStr = DateFormat('dd-MM-yy').format(_toDate);
      final filename = 'Ledger_${safeName}_${fromStr}_to_$toStr.xlsx';

      final opened = await ShareService.openXlsFile(
        bytes,
        filename: filename,
      );

      if (mounted && opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Opened $filename in Excel app. Edit & save there!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening XLS: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPartyId = null);
    }
  }

  /// Open bottom sheet to customize date from/till, set preferred name, and open or save/share
  void _openSaveSheet(
    CustomerModel party,
    List<InvoiceModel> allInvoices,
    BusinessModel business,
  ) {
    PartyXlsSaveSheet.show(
      context,
      party: party,
      allInvoices: allInvoices,
      business: business,
      initialFromDate: _fromDate,
      initialToDate: _toDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final customerProvider = Provider.of<CustomerProvider>(context);
    final business = Provider.of<BusinessProvider>(context).business;

    final allInvoices = invoiceProvider.allInvoices;
    final businessName = business.businessName.isNotEmpty ? business.businessName : 'My Business';

    // Filter customers by search
    final allCustomers = customerProvider.customers;
    final customers = _searchQuery.isEmpty
        ? allCustomers
        : allCustomers.where((c) {
            final q = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) || c.phone.contains(q);
          }).toList();

    // Build per-party summaries for the selected period
    final fromStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toEnd = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    Map<String, PartySummary> partySummaryMap = {};
    for (final inv in allInvoices) {
      final cid = inv.customerId;
      if (!partySummaryMap.containsKey(cid)) {
        partySummaryMap[cid] = PartySummary();
      }
      final summary = partySummaryMap[cid]!;
      // Overall totals (for balance)
      summary.totalBilled += inv.grandTotal;
      summary.totalPaid += inv.amountPaid;
      summary.totalDue += inv.balanceDue;
      // Period-specific
      if (!inv.invoiceDate.isBefore(fromStart) && !inv.invoiceDate.isAfter(toEnd)) {
        summary.periodBills++;
        summary.periodAmount += inv.grandTotal;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Party Ledger',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              businessName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: const [
          SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // ── Date Range Bar ──────────────────────────────────────────────
          _buildDateRangeBar(),

          // ── Search Bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Search party name or phone...',
                        hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      splashRadius: 16,
                      icon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          // ── Party count label ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
            child: Row(
              children: [
                Text(
                  '${customers.length} ${customers.length == 1 ? "Party" : "Parties"}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const Spacer(),
                const Text(
                  'Tap card for Period & Save • XLS to Open',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // ── Party List ───────────────────────────────────────────────────
          Expanded(
            child: customers.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: customers.length,
                    separatorBuilder: (_, b) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final party = customers[index];
                      final summary = partySummaryMap[party.id] ?? PartySummary();
                      final isLoading = _loadingPartyId == party.id;
                      return PartyLedgerCard(
                        party: party,
                        summary: summary,
                        isLoading: isLoading,
                        onOpenXls: isLoading
                            ? null
                            : () => _openPartyXls(party, allInvoices, business),
                        onTap: () => _openSaveSheet(party, allInvoices, business),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeBar() {
    final dfmt = DateFormat('dd MMM yyyy');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          // Quick Range Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _rangeOptions.map((r) {
                final isSelected = _selectedRange == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (r == 'Custom') {
                        _pickDateRange();
                      } else {
                        _applyDateRange(r);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Stepper + Active Date Range
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_left_rounded, size: 22, color: Color(0xFF2563EB)),
                onPressed: () => _navigatePeriod(false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          '${dfmt.format(_fromDate)} — ${dfmt.format(_toDate)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_calendar_outlined, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_right_rounded, size: 22, color: Color(0xFF2563EB)),
                onPressed: () => _navigatePeriod(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text('No Parties Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
          SizedBox(height: 4),
          Text('Add customers to see their ledgers here.', style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }
}

// ─── Party Summary Data ────────────────────────────────────────────────────────

class PartySummary {
  double totalBilled = 0;
  double totalPaid = 0;
  double totalDue = 0;
  int periodBills = 0;
  double periodAmount = 0;
}

// ─── Party Ledger Card ─────────────────────────────────────────────────────────

class PartyLedgerCard extends StatelessWidget {
  final CustomerModel party;
  final PartySummary summary;
  final bool isLoading;
  final VoidCallback? onOpenXls;
  final VoidCallback? onTap;

  const PartyLedgerCard({
    super.key,
    required this.party,
    required this.summary,
    required this.isLoading,
    required this.onOpenXls,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDue = summary.totalDue > 0;
    final initial = party.name.isNotEmpty ? party.name[0].toUpperCase() : 'P';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (party.phone.isNotEmpty)
                      Text(
                        party.phone,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (summary.periodBills > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${summary.periodBills} bills this period',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasDue ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hasDue ? 'Due: ₹${summary.totalDue.toStringAsFixed(0)}' : 'Settled',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: hasDue ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions: [Open in Excel App] + [Period / Save Options]
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Direct Open in Excel
                  isLoading
                      ? const SizedBox(
                          width: 38,
                          height: 38,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF16A34A)),
                          ),
                        )
                      : Tooltip(
                          message: 'Open directly in Excel app',
                          child: InkWell(
                            onTap: onOpenXls,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'XLS',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(width: 6),
                  // Save / Period Options sheet
                  Tooltip(
                    message: 'Date Period & Save options',
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF475569)),
                      ),
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
