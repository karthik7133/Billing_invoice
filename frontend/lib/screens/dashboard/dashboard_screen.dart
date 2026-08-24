import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/invoice_card.dart';
import '../invoices/create_invoice_screen.dart';
import '../invoices/invoice_detail_screen.dart';
import '../invoices/invoice_history_screen.dart';
import '../customers/add_edit_customer_screen.dart';
import '../products/add_edit_product_screen.dart';
import '../business/business_profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final invoiceProvider = Provider.of<InvoiceProvider>(context);

    final business = businessProvider.business;
    final metrics = invoiceProvider.getDashboardMetrics();
    final recentInvoices = invoiceProvider.invoices.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              business.businessName.isNotEmpty ? business.businessName : 'My Business',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (business.gstin.isNotEmpty)
              Text(
                'GSTIN: ${business.gstin}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.store_outlined, color: AppColors.primary),
            tooltip: 'Business Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const BusinessProfileScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'logout') {
                context.read<AuthProvider>().logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],

      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await invoiceProvider.fetchInvoices();
          await businessProvider.fetchBusinessProfile();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Highlight Banner / Sales Metrics
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: "Today's Sales",
                      value: CurrencyFormatter.format(metrics.todaySales),
                      subtitle: "Month: ${CurrencyFormatter.formatCompact(metrics.monthSales)}",
                      icon: Icons.trending_up_rounded,
                      accentColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'Unpaid / Due',
                      value: CurrencyFormatter.format(metrics.totalUnpaid),
                      subtitle: '${metrics.unpaidCount} Pending bills',
                      icon: Icons.pending_actions_rounded,
                      accentColor: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      title: 'Total Invoices',
                      value: '${metrics.totalInvoices}',
                      subtitle: '${metrics.paidCount} Fully Paid',
                      icon: Icons.receipt_long_rounded,
                      accentColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'All Time Sales',
                      value: CurrencyFormatter.format(metrics.totalSales),
                      subtitle: 'Active turnover',
                      icon: Icons.account_balance_wallet_outlined,
                      accentColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      icon: Icons.post_add_rounded,
                      label: 'New Invoice',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const CreateInvoiceScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      icon: Icons.person_add_outlined,
                      label: 'Add Customer',
                      color: AppColors.secondary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionButton(
                      context,
                      icon: Icons.add_box_outlined,
                      label: 'Add Product',
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (ctx) => const AddEditProductScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. Recent Invoices Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Invoices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const InvoiceHistoryScreen()),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (recentInvoices.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_outlined, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      const Text(
                        'No Invoices Generated Yet',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap the + button below to create your first GST invoice',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentInvoices.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final inv = recentInvoices[i];
                    return InvoiceCard(
                      invoice: inv,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => InvoiceDetailScreen(invoice: inv),
                          ),
                        );
                      },
                      onMarkPaid: () {
                        invoiceProvider.markInvoiceAsPaid(inv.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invoice ${inv.invoiceNumber} marked as PAID'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
