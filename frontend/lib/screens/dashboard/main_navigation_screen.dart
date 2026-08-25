import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/backend_sync_service.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/cloud_server_status_pill.dart';
import 'dashboard_screen.dart';
import '../products/product_list_screen.dart';
import '../business/business_profile_screen.dart';
import '../business/manage_companies_screen.dart';
import '../settings/party_settings_screen.dart';
import '../settings/invoice_print_settings_screen.dart';
import '../invoices/invoice_history_screen.dart';
import '../invoices/create_invoice_screen.dart';
import '../customers/customer_list_screen.dart';

/// Global key exposing tab-switching capability to nested screens (e.g. ManageCompaniesScreen)
final mainNavigationKey = GlobalKey<_MainNavigationScreenState>();

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key}) : super();

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Auto-load cached data immediately + trigger live sync
      _refreshAllData();

      // Register listener: if backend was sleeping and wakes up, auto-sync all data!
      BackendSyncService.instance.addOnAwakeCallback(_onServerAwake);
    });
  }

  void _onServerAwake() {
    if (mounted) {
      debugPrint('[MainNavigation] Server woke up! Triggering automatic data refresh...');
      _refreshAllData();
    }
  }

  void _refreshAllData() {
    final busP = context.read<BusinessProvider>();
    final custP = context.read<CustomerProvider>();
    final prodP = context.read<ProductProvider>();
    final invP = context.read<InvoiceProvider>();
    final authP = context.read<AuthProvider>();

    BackendSyncService.instance.forceSync(
      authProvider: authP,
      businessProvider: busP,
      customerProvider: custP,
      productProvider: prodP,
      invoiceProvider: invP,
    );
  }

  /// Called by ManageCompaniesScreen after a company switch to jump to the Home tab
  void switchToHomeTab() {
    if (mounted) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  void dispose() {
    BackendSyncService.instance.removeOnAwakeCallback(_onServerAwake);
    super.dispose();
  }

  // 4 tabs: HOME, DASHBOARD, ITEMS, MENU
  final List<Widget> _screens = const [
    DashboardScreen(),
    _AnalyticsDashboardScreen(),
    ProductListScreen(),
    _MenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _VyaparBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        onAddTap: () => _showAddActionSheet(context),
      ),
    );
  }

  void _showAddActionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose an action to get started',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              // 2x2 grid of action cards
              Row(
                children: [
                  _HomeActionCard(
                    icon: Icons.receipt_outlined,
                    label: 'Sale Invoice',
                    color: const Color(0xFF2563EB),
                    bg: const Color(0xFFEFF6FF),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _HomeActionCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Purchase',
                    color: const Color(0xFFEA580C),
                    bg: const Color(0xFFFFF7ED),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerListScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _HomeActionCard(
                    icon: Icons.payments_outlined,
                    label: 'Payment In',
                    color: const Color(0xFF059669),
                    bg: const Color(0xFFECFDF5),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerListScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  _HomeActionCard(
                    icon: Icons.people_outlined,
                    label: 'Add Party',
                    color: const Color(0xFF7C3AED),
                    bg: const Color(0xFFF5F3FF),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerListScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Home + Button Action Card ────────────────────────────────────────────────

class _HomeActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 5-Tab Bottom Navigation Bar with Centre + Button ────────────────────────

class _VyaparBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const _VyaparBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              _NavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'HOME',
                onTap: onTap,
              ),
              _NavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'ANALYTICS',
                onTap: onTap,
              ),
              // Centre + FAB
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),
              ),
              _NavItem(
                index: 2,
                currentIndex: currentIndex,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: 'ITEMS',
                onTap: onTap,
              ),
              _NavItem(
                index: 3,
                currentIndex: currentIndex,
                icon: Icons.menu_rounded,
                activeIcon: Icons.menu_open_rounded,
                label: 'MENU',
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;
    final color = isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: 23,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Analytics Dashboard Tab (DASHBOARD) ──────────────────────────────────────

class _AnalyticsDashboardScreen extends StatelessWidget {
  const _AnalyticsDashboardScreen();

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final metrics = invoiceProvider.getDashboardMetrics();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Business Analytics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CloudServerStatusPill(compact: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final busP = context.read<BusinessProvider>();
          final custP = context.read<CustomerProvider>();
          final prodP = context.read<ProductProvider>();
          final invP = context.read<InvoiceProvider>();
          await BackendSyncService.instance.forceSync(
            businessProvider: busP,
            customerProvider: custP,
            productProvider: prodP,
            invoiceProvider: invP,
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sales & Dues Metric Cards Grid
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
                      accentColor: AppColors.payableRed,
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
                      accentColor: AppColors.electricBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      title: 'All Time Turnover',
                      value: CurrencyFormatter.format(metrics.totalSales),
                      subtitle: 'Active turnover',
                      icon: Icons.account_balance_wallet_outlined,
                      accentColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Quick Reports & Actions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              _buildAnalyticsTile(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                title: 'View All Invoices & Sales Records',
                subtitle: 'Filter by date, payment status, and export PDF',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildAnalyticsTile(
                icon: Icons.post_add_rounded,
                iconColor: AppColors.vyaparPink,
                iconBg: AppColors.vyaparPinkLight,
                title: 'Create New GST Sale / Invoice',
                subtitle: 'Generate tax compliant invoice with auto calculations',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildAnalyticsTile(
                icon: Icons.sync_rounded,
                iconColor: const Color(0xFF0D9488),
                iconBg: const Color(0xFFF0FDFA),
                title: 'Synchronize Cloud Database',
                subtitle: 'Ensure all local and cloud billing records are synced',
                onTap: () {
                  final busP = context.read<BusinessProvider>();
                  final custP = context.read<CustomerProvider>();
                  final prodP = context.read<ProductProvider>();
                  final invP = context.read<InvoiceProvider>();
                  BackendSyncService.instance.forceSync(
                    businessProvider: busP,
                    customerProvider: custP,
                    productProvider: prodP,
                    invoiceProvider: invP,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cloud synchronization triggered!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}

// ─── Menu Tab (MENU & SETTINGS) ───────────────────────────────────────────────

class _MenuScreen extends StatelessWidget {
  const _MenuScreen();

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final business = businessProvider.business;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Settings & Business',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CloudServerStatusPill(compact: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Business Profile Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      business.businessName.isNotEmpty ? business.businessName[0].toUpperCase() : 'B',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.businessName.isNotEmpty ? business.businessName : 'My Business',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        business.gstin.isNotEmpty ? 'GSTIN: ${business.gstin}' : 'GST Billing Engine Active',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('COMPANY & WORKSPACE'),
          _buildMenuTile(
            icon: Icons.domain_rounded,
            title: 'Manage Companies',
            subtitle: 'Switch business profile, add companies or restore backup',
            badgeText: business.businessName.isNotEmpty ? business.businessName : 'Current',
            color: const Color(0xFFDC2626),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageCompaniesScreen()),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.store_outlined,
            title: 'Business Profile & Bank Details',
            subtitle: 'Manage GSTIN, Address, Bank A/C, IFSC, UPI ID',
            color: const Color(0xFF2563EB),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
              );
            },
          ),

          const SizedBox(height: 18),
          _buildSectionHeader('REPORTS & TRANSACTIONS'),
          _buildMenuTile(
            icon: Icons.receipt_long_outlined,
            title: 'Sales Reports & All Invoices',
            subtitle: 'View, filter, export and share sales ledger & PDFs',
            color: const Color(0xFF059669),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.shopping_bag_outlined,
            title: 'Purchase Transactions & Reports',
            subtitle: 'Inward supplies, purchase records & party dues',
            color: const Color(0xFFEA580C),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
              );
            },
          ),

          const SizedBox(height: 18),
          _buildSectionHeader('PRINTING & PARTY PREFERENCES'),
          _buildMenuTile(
            icon: Icons.print_outlined,
            title: 'Invoice Print & PDF Settings',
            subtitle: 'Crab logo toggle, footer bank info, A4/Thermal layouts',
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvoicePrintSettingsScreen()),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.people_outline_rounded,
            title: 'Party Settings',
            subtitle: 'Credit period rules, duplicate invoice numbers, statements',
            color: const Color(0xFF0891B2),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PartySettingsScreen()),
              );
            },
          ),

          const SizedBox(height: 18),
          _buildSectionHeader('DATA & ACCOUNT'),
          _buildMenuTile(
            icon: Icons.cloud_sync_outlined,
            title: 'Cloud Auto-Sync & Reconnect',
            subtitle: 'Force refresh backend data and verify cloud connection',
            color: const Color(0xFF2563EB),
            onTap: () {
              final busP = Provider.of<BusinessProvider>(context, listen: false);
              final custP = Provider.of<CustomerProvider>(context, listen: false);
              final prodP = Provider.of<ProductProvider>(context, listen: false);
              final invP = Provider.of<InvoiceProvider>(context, listen: false);
              final authP = Provider.of<AuthProvider>(context, listen: false);
              BackendSyncService.instance.forceSync(
                authProvider: authP,
                businessProvider: busP,
                customerProvider: custP,
                productProvider: prodP,
                invoiceProvider: invP,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing with Render cloud backend...'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.electricBlue,
                ),
              );
            },
          ),
          _buildMenuTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: 'Log out and clear local cached session',
            color: AppColors.payableRed,
            onTap: () {
              auth.logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    String? badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: (color ?? const Color(0xFF2563EB)).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color ?? const Color(0xFF2563EB), size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color == AppColors.payableRed ? AppColors.payableRed : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}

