import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/business_model.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../services/excel_export_service.dart';
import '../services/share_service.dart';

class PartyXlsSaveSheet extends StatefulWidget {
  final CustomerModel party;
  final List<InvoiceModel> allInvoices;
  final BusinessModel business;
  final DateTime initialFromDate;
  final DateTime initialToDate;

  const PartyXlsSaveSheet({
    super.key,
    required this.party,
    required this.allInvoices,
    required this.business,
    required this.initialFromDate,
    required this.initialToDate,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomerModel party,
    required List<InvoiceModel> allInvoices,
    required BusinessModel business,
    required DateTime initialFromDate,
    required DateTime initialToDate,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PartyXlsSaveSheet(
        party: party,
        allInvoices: allInvoices,
        business: business,
        initialFromDate: initialFromDate,
        initialToDate: initialToDate,
      ),
    );
  }

  @override
  State<PartyXlsSaveSheet> createState() => _PartyXlsSaveSheetState();
}

class _PartyXlsSaveSheetState extends State<PartyXlsSaveSheet> {
  late DateTime _fromDate;
  late DateTime _toDate;
  late TextEditingController _filenameController;
  bool _userEditedFilename = false;

  bool _isOpeningInExcel = false;
  bool _isSharing = false;

  final DateFormat _displayDfmt = DateFormat('dd MMM yyyy');
  final DateFormat _fileDfmt = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
    _filenameController = TextEditingController(text: _generateDefaultFilename());
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  String _sanitize(String text) {
    return text.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
  }

  String _generateDefaultFilename() {
    final safeName = _sanitize(widget.party.name);
    final fromStr = _fileDfmt.format(_fromDate);
    final toStr = _fileDfmt.format(_toDate);
    return 'Ledger_${safeName}_${fromStr}_to_$toStr';
  }

  void _updateFilenameIfDefault() {
    if (!_userEditedFilename) {
      setState(() {
        _filenameController.text = _generateDefaultFilename();
      });
    }
  }

  void _setPreset(String preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      switch (preset) {
        case 'Today':
          _fromDate = DateTime(now.year, now.month, now.day);
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
        case 'This FY':
          final fyYear = now.month >= 4 ? now.year : now.year - 1;
          _fromDate = DateTime(fyYear, 4, 1);
          _toDate = DateTime(fyYear + 1, 3, 31);
          break;
        case 'All Time':
          _fromDate = DateTime(2020, 1, 1);
          _toDate = DateTime(now.year, now.month, now.day);
          break;
      }
      _updateFilenameIfDefault();
    });
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF16A34A),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_fromDate.isAfter(_toDate)) {
          _toDate = _fromDate;
        }
        _updateFilenameIfDefault();
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF16A34A),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _updateFilenameIfDefault();
      });
    }
  }

  String _getFinalFilename() {
    var raw = _filenameController.text.trim();
    if (raw.isEmpty) {
      raw = _generateDefaultFilename();
    }
    // Remove invalid filename characters
    raw = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (raw.toLowerCase().endsWith('.xlsx')) {
      return raw;
    }
    return '$raw.xlsx';
  }

  Future<Uint8List?> _generateBytes() async {
    return await ExcelExportService.generatePartyLedgerXlsx(
      customer: widget.party,
      allInvoices: widget.allInvoices,
      fromDate: _fromDate,
      toDate: _toDate,
      business: widget.business,
    );
  }

  Future<void> _openInExcelApp() async {
    if (_isOpeningInExcel || _isSharing) return;
    HapticFeedback.lightImpact();
    setState(() => _isOpeningInExcel = true);

    try {
      final bytes = await _generateBytes();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Generated file is empty');
      }

      final filename = _getFinalFilename();
      final opened = await ShareService.openXlsFile(bytes, filename: filename);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  opened ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opened
                        ? 'Opening $filename in Excel app...'
                        : 'No direct Excel app found. Opened share menu.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: opened ? const Color(0xFF15803D) : const Color(0xFF2563EB),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningInExcel = false);
    }
  }

  Future<void> _saveAndShare() async {
    if (_isOpeningInExcel || _isSharing) return;
    HapticFeedback.lightImpact();
    setState(() => _isSharing = true);

    try {
      final bytes = await _generateBytes();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Generated file is empty');
      }

      final filename = _getFinalFilename();
      await ShareService.shareXlsFile(
        bytes,
        filename: filename,
        subject: 'Party Ledger — ${widget.party.name}',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing XLS: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final initial = widget.party.name.isNotEmpty ? widget.party.name[0].toUpperCase() : 'P';

    // Calculate count of invoices in this selected range
    final fromStart = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toEnd = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

    int billsCount = 0;
    double periodTotal = 0;
    for (final inv in widget.allInvoices) {
      if (inv.customerId == widget.party.id &&
          !inv.invoiceDate.isBefore(fromStart) &&
          !inv.invoiceDate.isAfter(toEnd)) {
        billsCount++;
        periodTotal += inv.grandTotal;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header with Party Info
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.party.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'XLS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.party.phone.isNotEmpty
                            ? widget.party.phone
                            : 'Party Ledger Export',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  splashRadius: 20,
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFE2E8F0)),

            // ── Section 1: Period Selection ─────────────────────────────────
            const Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF15803D)),
                SizedBox(width: 6),
                Text(
                  'SELECT PERIOD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quick Preset Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['This Month', 'Last Month', 'This FY', 'All Time', 'Today'].map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onPressed: () => _setPreset(p),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // From & Till Date Pickers
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickFromDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Date From',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _displayDfmt.format(_fromDate),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickToDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Date Till',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _displayDfmt.format(_toDate),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Period summary count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF15803D)),
                  const SizedBox(width: 6),
                  Text(
                    billsCount == 1 ? '1 bill in selected period' : '$billsCount bills in selected period',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                  ),
                  const Spacer(),
                  Text(
                    '₹${periodTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Section 2: Preferred File Name ──────────────────────────────
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF2563EB)),
                SizedBox(width: 6),
                Text(
                  'PREFERRED FILE NAME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _filenameController,
                      onChanged: (_) => _userEditedFilename = true,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter file name...',
                        hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '.xlsx',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The file will be saved and opened with this name in your Excel/Office app.',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 22),

            // ── Section 3: Action Buttons ───────────────────────────────────
            // 1. Primary: Open in Excel App
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_isOpeningInExcel || _isSharing) ? null : _openInExcelApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isOpeningInExcel
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text('Opening in Excel...', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_chart_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Open in Excel App (Edit & Save)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Secondary: Save & Share
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: (_isOpeningInExcel || _isSharing) ? null : _saveAndShare,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
                child: _isSharing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                          ),
                          SizedBox(width: 10),
                          Text('Sharing XLS...', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_rounded, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text(
                            'Save & Share XLS',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
