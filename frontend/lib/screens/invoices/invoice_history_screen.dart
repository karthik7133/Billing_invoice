import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/invoice_card.dart';
import '../../widgets/empty_state_widget.dart';
import 'create_invoice_screen.dart';
import 'invoice_detail_screen.dart';
import 'invoice_pdf_preview_screen.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _activeTab = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final invoices = invoiceProvider.invoices;

    // Compute summary totals for currently filtered view
    double filteredTotal = 0;
    double filteredPaid = 0;
    double filteredDue = 0;
    for (final inv in invoices) {
      if (inv.status != 'CANCELLED') {
        filteredTotal += inv.grandTotal;
        filteredPaid += inv.amountPaid;
        filteredDue += inv.balanceDue;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const CreateInvoiceScreen()),
              );
            },
            tooltip: 'Create Invoice',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => invoiceProvider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search by invoice number or customer...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          invoiceProvider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
            ),
          ),

          // 2. Status Tabs Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildStatusTab('ALL', 'All Invoices'),
                const SizedBox(width: 8),
                _buildStatusTab('UNPAID', 'Unpaid / Due'),
                const SizedBox(width: 8),
                _buildStatusTab('PAID', 'Paid'),
                const SizedBox(width: 8),
                _buildStatusTab('PARTIALLY_PAID', 'Partial'),
                const SizedBox(width: 8),
                _buildStatusTab('DRAFT', 'Drafts'),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Mini Aggregate Summary Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Amount', CurrencyFormatter.format(filteredTotal), AppColors.textPrimary),
                Container(height: 24, width: 1, color: AppColors.divider),
                _buildSummaryStat('Paid', CurrencyFormatter.format(filteredPaid), AppColors.success),
                Container(height: 24, width: 1, color: AppColors.divider),
                _buildSummaryStat('Due / Balance', CurrencyFormatter.format(filteredDue), AppColors.error),
              ],
            ),
          ),

          // 4. Invoices List
          Expanded(
            child: invoices.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No Invoices Found',
                    description: _searchController.text.isNotEmpty
                        ? 'No invoices match your search keyword.'
                        : 'No invoices found under the selected filter.',
                    buttonText: 'Create New Invoice',
                    onButtonPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const CreateInvoiceScreen()),
                      );
                    },
                  )
                : RefreshIndicator(
                    onRefresh: () => invoiceProvider.fetchInvoices(),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: invoices.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final invoice = invoices[i];
                        return InvoiceCard(
                          invoice: invoice,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => InvoiceDetailScreen(invoice: invoice),
                              ),
                            );
                          },
                          onMarkPaid: () {
                            invoiceProvider.markInvoiceAsPaid(invoice.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invoice ${invoice.invoiceNumber} marked as PAID'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          onShare: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => InvoicePdfPreviewScreen(invoice: invoice),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String statusKey, String label) {
    final isSelected = _activeTab == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      onSelected: (val) {
        setState(() {
          _activeTab = statusKey;
        });
        Provider.of<InvoiceProvider>(context, listen: false).setStatusFilter(statusKey);
      },
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
