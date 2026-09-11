import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../core/utils/currency_formatter.dart';

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
    final success = await invProvider.restoreInvoice(invoice.id);

    if (mounted) {
      setState(() {
        _processingIds.remove(invoice.id);
        if (success) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Permanently?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete Sale #${invoice.invoiceNumber}. This action cannot be undone.',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry permanently deleted')),
                  );
                } else {
                  _loadRecycleBin();
                }
              }
            },
            child: const Text('Delete Forever', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyBin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Empty Recycle Bin?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'All entries in the Recycle Bin will be permanently destroyed. Are you sure?',
          style: TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
              await invProvider.emptyRecycleBin();
              if (mounted) {
                _loadRecycleBin();
              }
            },
            child: const Text('Empty All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            const Text(
              'Recycle Bin',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            Text(
              widget.customerName != null ? '${widget.customerName} • 30-day retention' : 'Items kept for 30 days',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmEmptyBin,
              icon: const Icon(Icons.delete_sweep, size: 18, color: Color(0xFFEF4444)),
              label: const Text(
                'Empty Bin',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_outline, size: 40, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Recycle Bin is Empty',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Deleted party entries are temporarily stored here for 30 days before being automatically purged.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecycleBin,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final inv = _items[i];
                      final daysLeft = _calcDaysRemaining(inv.deletedAt);
                      final isRestoring = _processingIds.contains(inv.id);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '#${inv.invoiceNumber}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(inv.invoiceDate),
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Countdown badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: daysLeft <= 5
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 12,
                                        color: daysLeft <= 5 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$daysLeft days left',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: daysLeft <= 5 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (inv.description.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          inv.description,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  CurrencyFormatter.format(inv.grandTotal),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: isRestoring ? null : () => _confirmDeleteForever(inv),
                                    icon: const Icon(Icons.delete_forever, size: 16, color: Color(0xFFEF4444)),
                                    label: const Text(
                                      'Delete Forever',
                                      style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFFECACA)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: isRestoring ? null : () => _restoreItem(inv),
                                    icon: isRestoring
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.restore, size: 16, color: Colors.white),
                                    label: Text(
                                      isRestoring ? 'Restoring...' : 'Restore',
                                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
