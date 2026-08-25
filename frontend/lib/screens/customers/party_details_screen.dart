import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/pdf_invoice_service.dart';
import '../../services/share_service.dart';
import '../../providers/business_provider.dart';
import '../../widgets/pdf_display_options_sheet.dart';
import '../invoices/create_invoice_screen.dart';
import '../invoices/invoice_detail_screen.dart';
import '../invoices/invoice_pdf_preview_screen.dart';
import 'add_edit_customer_screen.dart';
import 'party_statement_screen.dart';

class PartyDetailsScreen extends StatefulWidget {
  final CustomerModel customer;

  const PartyDetailsScreen({super.key, required this.customer});

  @override
  State<PartyDetailsScreen> createState() => _PartyDetailsScreenState();
}

class _PartyDetailsScreenState extends State<PartyDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  late CustomerModel _customer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);
    final invoiceProvider = Provider.of<InvoiceProvider>(context);

    // Get current customer if updated
    final liveCustomer = customerProvider.getCustomerById(_customer.id) ?? _customer;
    final allPartyInvoices = invoiceProvider.getInvoicesForCustomer(liveCustomer.id);

    final filteredInvoices = allPartyInvoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.status.toLowerCase().contains(q) ||
          inv.grandTotal.toString().contains(q);
    }).toList();

    final totalReceivable = allPartyInvoices.fold<double>(
      0.0,
      (sum, inv) => sum + inv.balanceDue,
    );

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
          'Party Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.black87),
            tooltip: 'Edit Party',
            onPressed: () async {
              final updated = await Navigator.of(context).push<CustomerModel>(
                MaterialPageRoute(
                  builder: (ctx) => AddEditCustomerScreen(customer: liveCustomer),
                ),
              );
              if (updated != null) {
                setState(() => _customer = updated);
              }
            },
          ),
          // ─── 3-dot More Actions dropdown ─────────────────────────────
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'delete') {
                _confirmDelete(context, liveCustomer);
              } else if (val == 'send_pdf') {
                _sharePdfStatement(context, liveCustomer, allPartyInvoices);
              } else if (val == 'party_statement') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PartyStatementScreen(customer: liveCustomer),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'party_statement',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 10),
                    Text('Party Statement', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'send_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 10),
                    Text('Send PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Delete Party', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Party Summary Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Party Name & Phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            liveCustomer.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => AddEditCustomerScreen(customer: liveCustomer),
                                ),
                              );
                            },
                            child: Text(
                              liveCustomer.phone.isNotEmpty ? liveCustomer.phone : 'Add Phone',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: liveCustomer.phone.isNotEmpty
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right: Receivable / Balance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_downward_rounded,
                              size: 16,
                              color: AppColors.receivableGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Receivable: ${CurrencyFormatter.format(totalReceivable)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.receivableGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'No Credit Limit Set',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                // Reminder & Statement Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ShareService.shareText(
                            text:
                                'Dear ${liveCustomer.name},\nYour outstanding balance with our business is ${CurrencyFormatter.format(totalReceivable)}. Please make the payment at your earliest convenience.\nThank you!',
                            subject: 'Payment Reminder - Outstanding Balance',
                          );
                        },
                        icon: const Icon(Icons.notifications_none_rounded, size: 16, color: Color(0xFF2563EB)),
                        label: const Text(
                          'Send Reminder',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PartyStatementScreen(customer: liveCustomer),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF2563EB)),
                        label: const Text(
                          'Party Statement',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Search Transactions by #no or status...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      splashRadius: 18,
                      icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
          ),

          // 3. Transactions List
          Expanded(
            child: filteredInvoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No matching transactions found'
                              : 'No transactions for this party yet',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "+" below to create a bill for this party.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filteredInvoices.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final inv = filteredInvoices[index];
                      return _buildPartyTransactionCard(context, inv, invoiceProvider);
                    },
                  ),
          ),

          // 4. Bottom Sticky Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Take Payment (Blue Pill)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _showTakePaymentDialog(context, liveCustomer, invoiceProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Take Payment...',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Centre "+" circle — now opens popup
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E88E5), width: 1.5),
                      color: Colors.white,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add, color: Color(0xFF1E88E5), size: 24),
                      onPressed: () => _showAddActionSheet(context, liveCustomer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add Sale → directly to CreateInvoiceScreen
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateInvoiceScreen(preselectedCustomer: liveCustomer),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.vyaparPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add Sale',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Add Action Sheet (Sale Invoice / Purchase Transaction) ────────────────

  void _showAddActionSheet(BuildContext context, CustomerModel customer) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _ActionTile(
                icon: Icons.receipt_outlined,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                title: 'Sale Invoice',
                subtitle: 'Create a new sale invoice for this party',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateInvoiceScreen(preselectedCustomer: customer),
                    ),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.shopping_cart_outlined,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                title: 'Purchase Transaction',
                subtitle: 'Record a purchase from this party',
                onTap: () {
                  Navigator.pop(ctx);
                  // Purchase transaction — for now navigates to invoice with a note
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateInvoiceScreen(preselectedCustomer: customer),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Transaction Card ─────────────────────────────────────────────────────

  Widget _buildPartyTransactionCard(
    BuildContext context,
    InvoiceModel invoice,
    InvoiceProvider invoiceProvider,
  ) {
    final isPaid = invoice.isPaid;
    final dateStr = DateFormat('dd MMM, yy').format(invoice.invoiceDate);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => InvoiceDetailScreen(invoice: invoice)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Type & Badge — "Purchase" from customer's perspective
                Row(
                  children: [
                    const Text(
                      'Purchase',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFE6F7F0) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPaid ? AppColors.receivableGreen : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                // Invoice No & Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '#${invoice.invoiceNumber}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Total & Balance
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(invoice.grandTotal),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Balance', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(invoice.balanceDue),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: invoice.balanceDue > 0 ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Print, Share, 3 dots actions
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 20, color: Color(0xFF64748B)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => InvoicePdfPreviewScreen(invoice: invoice),
                          ),
                        );
                      },
                      tooltip: 'Print / PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFF64748B)),
                      onPressed: () async {
                        final bytes = await PdfInvoiceService.generateTaxInvoicePdf(invoice);
                        await ShareService.sharePdf(bytes, filename: 'Invoice_${invoice.invoiceNumber}.pdf');
                      },
                      tooltip: 'Share',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (action) {
                        if (action == 'mark_paid') {
                          invoiceProvider.markInvoiceAsPaid(invoice.id);
                        } else if (action == 'delete') {
                          invoiceProvider.deleteInvoice(invoice.id);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!isPaid)
                          const PopupMenuItem(
                            value: 'mark_paid',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                                SizedBox(width: 8),
                                Text('Mark as Paid'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
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

  // ─── PDF Statement Sharing (Shows "What to display on PDF?" sheet) ───────

  void _sharePdfStatement(
    BuildContext context,
    CustomerModel customer,
    List<InvoiceModel> invoices,
  ) {
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final now = DateTime.now();
    final defaultFileName = '${customer.name.replaceAll(' ', '_').replaceAll('/', '_')}_${DateFormat('dd-MM-yyyy').format(now)}';

    PdfDisplayOptionsSheet.show(
      context,
      defaultFileName: defaultFileName,
      initialShowItemDetails: true,
      initialShowDescription: false,
      initialShowPaymentStatus: false,
      initialShowPaymentInfo: true,
      onApply: ({
        required String fileName,
        required bool showItemDetails,
        required bool showDescription,
        required bool showPaymentStatus,
        required bool showPaymentInfo,
      }) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final fromDate = DateTime(now.year, now.month, 1);
          final toDate = now;
          final bytes = await PdfInvoiceService.generatePartyStatementPdf(
            customer: customer,
            invoices: invoices,
            fromDate: fromDate,
            toDate: toDate,
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
            SnackBar(content: Text('PDF error: $e'), backgroundColor: AppColors.error),
          );
        }
      },
    );
  }

  // ─── Take Payment Dialog ──────────────────────────────────────────────────

  void _showTakePaymentDialog(
    BuildContext context,
    CustomerModel customer,
    InvoiceProvider invoiceProvider,
  ) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Record Payment - ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the payment amount received from this party:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5)),
            onPressed: () {
              final val = double.tryParse(amountController.text.trim());
              if (val != null && val > 0) {
                final unpaidInvoices = invoiceProvider
                    .getInvoicesForCustomer(customer.id)
                    .where((inv) => inv.balanceDue > 0)
                    .toList();
                double remaining = val;
                for (final inv in unpaidInvoices) {
                  if (remaining <= 0) break;
                  final payForThis = remaining >= inv.balanceDue ? inv.balanceDue : remaining;
                  invoiceProvider.updatePayment(inv.id, inv.amountPaid + payForThis);
                  remaining -= payForThis;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment of ₹$val recorded for ${customer.name}'),
                    backgroundColor: AppColors.receivableGreen,
                  ),
                );
              }
            },
            child: const Text('Save Payment'),
          ),
        ],
      ),
    );
  }

  // ─── Confirm Delete ───────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Party?'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Provider.of<CustomerProvider>(context, listen: false).deleteCustomer(customer.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Action Tile for Bottom Sheet ────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }
}
