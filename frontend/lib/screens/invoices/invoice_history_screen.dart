import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/invoice_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/cloud_server_status_pill.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Invoice History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        actions: [
          const CloudServerStatusPill(compact: true),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF2563EB)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const CreateInvoiceScreen()),
              );
            },
            tooltip: 'Create Invoice',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    child: Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 19),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => invoiceProvider.setSearchQuery(val),
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Search by invoice number or customer...',
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
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      splashRadius: 18,
                      icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _searchController.clear();
                        invoiceProvider.setSearchQuery('');
                      },
                    ),
                ],
              ),
            ),
          ),

          // 2. Status Tabs Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Total Sales', CurrencyFormatter.format(filteredTotal), const Color(0xFF0F172A)),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildSummaryStat('Total Paid', CurrencyFormatter.format(filteredPaid), AppColors.receivableGreen),
                Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                _buildSummaryStat('Total Due', CurrencyFormatter.format(filteredDue), AppColors.payableRed),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                                backgroundColor: AppColors.receivableGreen,
                                behavior: SnackBarBehavior.floating,
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
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        width: 1,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
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
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
