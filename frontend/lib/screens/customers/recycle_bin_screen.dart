import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/platform_helper.dart';
import '../../widgets/desktop_container.dart';

class RecycleBinScreen extends StatefulWidget {
  final String? customerId;
  final String? customerName;

  const RecycleBinScreen({
    super.key,
    this.customerId,
    this.customerName,
  });

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  bool _isLoading = true;
  bool _hasChanged = false;
  List<InvoiceModel> _items = [];
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadRecycleBin(showSpinner: true);
  }

  Future<void> _loadRecycleBin({bool showSpinner = false}) async {
    if (showSpinner && _items.isEmpty) {
      setState(() => _isLoading = true);
    }
    final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final list = await invProvider.getRecycleBinInvoices();

    if (widget.customerId != null) {
      _items = list.where((inv) => inv.customerId == widget.customerId).toList();
    } else {
      _items = list;
    }

    // Sort newest deleted first
    _items.sort((a, b) {
      final aDate = a.deletedAt ?? DateTime.now();
      final bDate = b.deletedAt ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int _calcDaysRemaining(DateTime? deletedAt) {
    if (deletedAt == null) return 30;
    final daysPassed = DateTime.now().difference(deletedAt).inDays;
    final remaining = 30 - daysPassed;
    return remaining.clamp(0, 30);
  }

  void _restoreItem(InvoiceModel invoice) async {
    if (_processingIds.contains(invoice.id)) return;

    setState(() {
      _processingIds.add(invoice.id);
    });

    final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final success = await invProvider.restoreInvoice(invoice.id, restoredInvoice: invoice);

    if (mounted) {
      setState(() {
        _processingIds.remove(invoice.id);
        if (success) {
          _hasChanged = true;
          _items.removeWhere((i) => i.id == invoice.id);
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale #${invoice.invoiceNumber} restored successfully'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to restore entry. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _confirmDeleteForever(InvoiceModel invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Permanently?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete Sale #${invoice.invoiceNumber} (${CurrencyFormatter.format(invoice.grandTotal)}). This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13.5, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final invId = invoice.id;
              setState(() {
                _items.removeWhere((i) => i.id == invId);
              });
              final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
              final ok = await invProvider.permanentlyDeleteInvoice(invId);
              if (mounted) {
                if (ok) {
                  _hasChanged = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sale #${invoice.invoiceNumber} permanently deleted'),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
                } else {
                  _loadRecycleBin();
                }
              }
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyBin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Empty Recycle Bin?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'All ${_items.length} deleted ${_items.length == 1 ? "entry" : "entries"} in the Recycle Bin will be permanently destroyed. Are you sure?',
          style: const TextStyle(color: Color(0xFF475569), fontSize: 13.5, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
              await invProvider.emptyRecycleBin();
              if (mounted) {
                _hasChanged = true;
                _loadRecycleBin();
              }
            },
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Empty All', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformHelper.isDesktop;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanged);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.pop(context, _hasChanged),
            tooltip: 'Back',
          ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recycle Bin',
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              widget.customerName != null
                  ? '${widget.customerName} • 30-day retention'
                  : 'Items kept for 30 days before permanent deletion',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _confirmEmptyBin,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                  label: const Text(
                    'Empty Bin',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECACA), width: 1.0),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 14 : 10,
                      vertical: isDesktop ? 8 : 6,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: DesktopContainer(
        maxWidth: 960,
        desktopPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadRecycleBin,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 0 : 14,
                        vertical: 14,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length + 1,
                      separatorBuilder: (_, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return _buildInfoBanner();
                        }
                        final inv = _items[i - 1];
                        final daysLeft = _calcDaysRemaining(inv.deletedAt);
                        final isRestoring = _processingIds.contains(inv.id);

                        return _RecycleBinItemCard(
                          invoice: inv,
                          daysLeft: daysLeft,
                          isRestoring: isRestoring,
                          onDeleteForever: () => _confirmDeleteForever(inv),
                          onRestore: () => _restoreItem(inv),
                        );
                      },
                    ),
                  ),
      ),
    ),
  );
}

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_delete_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_items.length} ${_items.length == 1 ? "Sale" : "Sales"} in Recycle Bin',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Deleted items are kept for 30 days before being automatically purged. You can restore or delete them forever.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3B82F6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.delete_sweep_outlined, size: 42, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Recycle Bin is Empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: const Text(
                'Deleted party sales are temporarily stored here for 30 days before being automatically purged.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Return Back', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF93C5FD)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecycleBinItemCard extends StatefulWidget {
  final InvoiceModel invoice;
  final int daysLeft;
  final bool isRestoring;
  final VoidCallback onDeleteForever;
  final VoidCallback onRestore;

  const _RecycleBinItemCard({
    required this.invoice,
    required this.daysLeft,
    required this.isRestoring,
    required this.onDeleteForever,
    required this.onRestore,
  });

  @override
  State<_RecycleBinItemCard> createState() => _RecycleBinItemCardState();
}

class _RecycleBinItemCardState extends State<_RecycleBinItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformHelper.isDesktop;
    final inv = widget.invoice;
    final daysLeft = widget.daysLeft;
    final isRestoring = widget.isRestoring;

    return MouseRegion(
      onEnter: isDesktop ? (_) => setState(() => _isHovered = true) : null,
      onExit: isDesktop ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(isDesktop ? 16 : 14),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFFAFCFF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.4 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Row: Sale #, Sale Date, and Days Left Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDBEAFE), width: 0.8),
                        ),
                        child: Text(
                          '#${inv.invoiceNumber}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(inv.invoiceDate),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      if (inv.items.isNotEmpty)
                        Text(
                          '• ${inv.items.length} ${inv.items.length == 1 ? "item" : "items"}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Days Left Countdown badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: daysLeft <= 5 ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: daysLeft <= 5 ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        daysLeft <= 5 ? Icons.warning_amber_rounded : Icons.hourglass_bottom_rounded,
                        size: 13,
                        color: daysLeft <= 5 ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4.5),
                      Text(
                        '$daysLeft ${daysLeft == 1 ? "day" : "days"} left',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: daysLeft <= 5 ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 2. Middle Row: Customer Info & Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.customerSnapshot.name.isNotEmpty ? inv.customerSnapshot.name : 'Customer',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (inv.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          inv.description,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  CurrencyFormatter.format(inv.grandTotal),
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // 3. Bottom Action Row: Deletion timestamp & Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Deletion timestamp (if available)
                if (inv.deletedAt != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Deleted ${DateFormat('dd MMM, hh:mm a').format(inv.deletedAt!)}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),

                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Delete Forever Button
                    OutlinedButton.icon(
                      onPressed: isRestoring ? null : widget.onDeleteForever,
                      icon: const Icon(Icons.delete_forever_rounded, size: 17, color: Color(0xFFEF4444)),
                      label: const Text(
                        'Delete Forever',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECACA), width: 1.0),
                        backgroundColor: const Color(0xFFFEF2F2),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 15 : 12,
                          vertical: isDesktop ? 10 : 8,
                        ),
                        minimumSize: Size(0, isDesktop ? 38 : 34),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Restore Button
                    ElevatedButton.icon(
                      onPressed: isRestoring ? null : widget.onRestore,
                      icon: isRestoring
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.restore_rounded, size: 17, color: Colors.white),
                      label: Text(
                        isRestoring ? 'Restoring...' : 'Restore Sale',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 18 : 14,
                          vertical: isDesktop ? 10 : 8,
                        ),
                        minimumSize: Size(0, isDesktop ? 38 : 34),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  }
}
