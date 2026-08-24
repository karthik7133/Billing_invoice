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
import '../invoices/create_invoice_screen.dart';
import '../invoices/invoice_detail_screen.dart';
import '../invoices/invoice_pdf_preview_screen.dart';
import 'add_edit_customer_screen.dart';

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (val) {
              if (val == 'delete') {
                _confirmDelete(context, liveCustomer);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Delete Party', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Party Summary Card (Image 3)
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
                          final statement = 'Party Statement for ${liveCustomer.name}\nTotal Invoices: ${allPartyInvoices.length}\nOutstanding Balance: ${CurrencyFormatter.format(totalReceivable)}';
                          ShareService.shareText(text: statement, subject: 'Party Statement - ${liveCustomer.name}');
                        },
                        icon: const Icon(Icons.receipt_long_outlined, size: 16, color: Color(0xFF2563EB)),
                        label: const Text(
                          'Send Statement',
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
                          'Tap "Add Sale" below to create a bill for this party.',
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

          // 4. Bottom Sticky Action Bar (Image 3)
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
                  // Centre "+" circle
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
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => CreateInvoiceScreen(preselectedCustomer: liveCustomer),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add Sale (Red/Pink Pill)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => CreateInvoiceScreen(preselectedCustomer: liveCustomer),
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
                // Type & Badge
                Row(
                  children: [
                    const Text(
                      'Sale',
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
                            child: Text('Mark as Paid'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Sale', style: TextStyle(color: Colors.redAccent)),
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
                // Update party outstanding invoices
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
