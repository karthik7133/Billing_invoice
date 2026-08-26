import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/backend_sync_service.dart';
import '../../services/pdf_invoice_service.dart';
import '../../services/share_service.dart';
import '../../widgets/cloud_server_status_pill.dart';
import '../../widgets/pdf_progress_dialog.dart';
import '../business/business_profile_screen.dart';
import '../customers/add_edit_customer_screen.dart';
import '../customers/party_details_screen.dart';
import '../invoices/create_invoice_screen.dart';
import '../invoices/invoice_detail_screen.dart';
import '../invoices/invoice_history_screen.dart';
import '../invoices/invoice_pdf_preview_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0 = Transaction Details, 1 = Party Details
  int _selectedTab = 1;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authP = Provider.of<AuthProvider>(context, listen: false);
    final custP = Provider.of<CustomerProvider>(context, listen: false);
    final invP = Provider.of<InvoiceProvider>(context, listen: false);
    final busP = Provider.of<BusinessProvider>(context, listen: false);
    final prodP = Provider.of<ProductProvider>(context, listen: false);

    // ── Always re-inject active company BEFORE any fetch ─────────────────────
    // busP.business.id may be a local seed ID on first load, but ensureInitialized
    // guarantees we read the cache-persisted active company correctly.
    await busP.ensureInitialized();
    final activeId = busP.activeCompanyId;
    if (activeId.isNotEmpty) {
      custP.setActiveCompany(activeId);
      invP.setActiveCompany(activeId);
    }
    // ─────────────────────────────────────────────────────────────────────────

    if (!mounted) return;

    await BackendSyncService.instance.forceSync(
      authProvider: authP,
      businessProvider: busP,
      customerProvider: custP,
      productProvider: prodP,
      invoiceProvider: invP,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final customerProvider = Provider.of<CustomerProvider>(context);
    final invoiceProvider = Provider.of<InvoiceProvider>(context);

    final businessName = businessProvider.business.businessName.isNotEmpty
        ? businessProvider.business.businessName
        : 'My Business';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildTopHeader(context, businessName),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // 1. Top Segmented Pills (Transaction Details vs Party Details)
            _buildSegmentedTabSelector(customerProvider.customers.length, invoiceProvider.invoices.length),

            // 2. Quick Links Section
            _buildQuickLinksRow(),

            // 3. Search & Filter Bar
            _buildSearchBar(),

            const SizedBox(height: 4),

            // 4. Main List: Party Details or Transaction Details
            Expanded(
              child: _selectedTab == 1
                  ? _buildPartyDetailsList(customerProvider, invoiceProvider)
                  : _buildTransactionDetailsList(invoiceProvider),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  // ─── 1. Header (Logo, Title, Cloud Pill, Sync) ─────────────────────────────
  PreferredSizeWidget _buildTopHeader(BuildContext context, String businessName) {
    final business = context.read<BusinessProvider>().business;
    final logoUrl = business.logo;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leadingWidth: 44,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const BusinessProfileScreen()),
          ),
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: logoUrl.isEmpty
                    ? const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: logoUrl.isNotEmpty ? Colors.white : null,
                borderRadius: BorderRadius.circular(10),
                border: logoUrl.isNotEmpty ? Border.all(color: const Color(0xFFE2E8F0), width: 1.0) : null,
                image: logoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(logoUrl),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: logoUrl.isEmpty
                  ? Center(
                      child: Text(
                        businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
      title: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => const BusinessProfileScreen()),
        ),
        child: Text(
          businessName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      actions: [
        const CloudServerStatusPill(compact: true),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.sync_rounded, color: Color(0xFF64748B), size: 21),
          tooltip: 'Sync with Cloud Server',
          onPressed: _loadData,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // ─── 2. Segmented Pill Tabs (Transaction Details vs Party Details) ─────────
  Widget _buildSegmentedTabSelector(int partyCount, int txnCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Transaction Details Tab
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedTab = 0;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _selectedTab == 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Transaction Details',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                            color: _selectedTab == 0 ? AppColors.electricBlue : const Color(0xFF64748B),
                          ),
                        ),
                        if (txnCount > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _selectedTab == 0 ? const Color(0xFFEFF6FF) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$txnCount',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _selectedTab == 0 ? AppColors.electricBlue : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Party Details Tab
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedTab = 1;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _selectedTab == 1
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Party Details',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                            color: _selectedTab == 1 ? AppColors.electricBlue : const Color(0xFF64748B),
                          ),
                        ),
                        if (partyCount > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: _selectedTab == 1 ? const Color(0xFFEFF6FF) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$partyCount',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _selectedTab == 1 ? AppColors.electricBlue : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. Quick Links Row ───────────────────────────────────────────────────
  Widget _buildQuickLinksRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _selectedTab == 1
                ? [
                    _buildQuickLinkItem(
                      icon: Icons.people_outline_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      label: 'All Parties',
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.person_add_alt_1_outlined,
                      iconBg: const Color(0xFFFFECEF),
                      iconColor: AppColors.vyaparPink,
                      label: 'New Party',
                      onTap: () async {
                        final created = await Navigator.of(context).push<CustomerModel>(
                          MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
                        );
                        if (mounted && created != null) {
                          Provider.of<CustomerProvider>(context, listen: false).fetchCustomers();
                        }
                      },
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.storefront_outlined,
                      iconBg: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      label: 'Profile',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                        );
                      },
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.receipt_long_outlined,
                      iconBg: const Color(0xFFF5F3FF),
                      iconColor: const Color(0xFF7C3AED),
                      label: 'Sales Report',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
                        );
                      },
                    ),
                  ]
                : [
                    _buildQuickLinkItem(
                      icon: Icons.note_add_outlined,
                      iconBg: const Color(0xFFFFECEF),
                      iconColor: AppColors.vyaparPink,
                      label: 'Add Sale',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                        );
                      },
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.analytics_outlined,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF0284C7),
                      label: 'Sale Report',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
                        );
                      },
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.settings_outlined,
                      iconBg: const Color(0xFFF8FAFC),
                      iconColor: const Color(0xFF475569),
                      label: 'Settings',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                        );
                      },
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.history_rounded,
                      iconBg: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      label: 'History',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
                        );
                      },
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  // ─── 4. Search & Filter Bar ───────────────────────────────────────────────
  Widget _buildSearchBar() {
    final hint = _selectedTab == 1 ? 'Search party by name or phone...' : 'Search sale by #no or customer...';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        height: 44,
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
              child: Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 19),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  // ─── 5. Party Details List ────────────────────────────────────────────────
  Widget _buildPartyDetailsList(
    CustomerProvider customerProvider,
    InvoiceProvider invoiceProvider,
  ) {
    var parties = customerProvider.customers;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      parties = parties.where((p) => p.name.toLowerCase().contains(q) || p.phone.contains(q)).toList();
    }

    if (parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline, size: 40, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No parties matching "$_searchQuery"' : 'No Parties Added Yet',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap "+ Add New Party" below to record party balances',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 85),
      itemCount: parties.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final party = parties[index];
        final partyInvoices = invoiceProvider.getInvoicesForCustomer(party.id);
        final calculatedBalance = partyInvoices.fold<double>(
          party.openingBalance,
          (sum, inv) => sum + inv.balanceDue,
        );

        final dateText = party.lastTransactionDate != null
            ? DateFormat('dd MMM, yy').format(party.lastTransactionDate!)
            : 'No transactions';

        final isReceivable = calculatedBalance >= 0;
        final balanceAbs = calculatedBalance.abs();

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (c) => PartyDetailsScreen(customer: party)),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Avatar + Name + Date
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(
                            party.name.isNotEmpty ? party.name[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              party.name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateText,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: Balance & Status Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(balanceAbs),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isReceivable
                            ? (balanceAbs > 0 ? AppColors.receivableGreenLight : const Color(0xFFF1F5F9))
                            : AppColors.payableRedLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isReceivable
                            ? (balanceAbs > 0 ? "You'll Get" : 'Settled')
                            : "You'll Give",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isReceivable
                              ? (balanceAbs > 0 ? AppColors.receivableGreen : const Color(0xFF64748B))
                              : AppColors.payableRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 6. Transaction Details List ──────────────────────────────────────────
  Widget _buildTransactionDetailsList(InvoiceProvider invoiceProvider) {
    var invoices = invoiceProvider.invoices;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      invoices = invoices.where((i) {
        return i.invoiceNumber.toLowerCase().contains(q) ||
            i.customerSnapshot.name.toLowerCase().contains(q) ||
            i.grandTotal.toString().contains(q);
      }).toList();
    }

    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No sales matching "$_searchQuery"' : 'No Transactions Yet',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap "+ Add New Sale" below to create your first invoice',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 85),
      itemCount: invoices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final inv = invoices[index];
        final isPaid = inv.isPaid;
        final dateStr = DateFormat('dd MMM, yy').format(inv.invoiceDate);

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (c) => InvoiceDetailScreen(invoice: inv)),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Customer Name | #InvoiceNo | Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        inv.customerSnapshot.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${inv.invoiceNumber}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isPaid ? AppColors.paidGreenLight : AppColors.unpaidOrangeLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'SALE : PAID' : 'SALE : UNPAID',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isPaid ? AppColors.receivableGreen : AppColors.unpaidOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Bottom Row: Total | Balance | Print / Share / More
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Amount', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(inv.grandTotal),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(width: 22),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Balance Due', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(inv.balanceDue),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: inv.balanceDue > 0 ? AppColors.payableRed : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 20, color: Color(0xFF64748B)),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (c) => InvoicePdfPreviewScreen(invoice: inv)),
                            );
                          },
                          tooltip: 'Print / PDF',
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFF64748B)),
                          onPressed: () async {
                            PdfProgressDialog.show(context, message: 'Preparing Invoice PDF...');
                            try {
                              final bytes = await PdfInvoiceService.generateTaxInvoicePdf(inv);
                              await ShareService.sharePdf(bytes, filename: 'Invoice_${inv.invoiceNumber}.pdf');
                            } finally {
                              PdfProgressDialog.hide();
                            }
                          },
                          tooltip: 'Share',
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                          onSelected: (action) {
                            if (action == 'mark_paid') {
                              invoiceProvider.markInvoiceAsPaid(inv.id);
                            } else if (action == 'delete') {
                              invoiceProvider.deleteInvoice(inv.id);
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
      },
    );
  }

  // ─── 7. Floating Action Button ────────────────────────────────────────────
  Widget _buildFloatingActionButton(BuildContext context) {
    if (_selectedTab == 1) {
      return ElevatedButton.icon(
        onPressed: () async {
          final created = await Navigator.of(context).push<CustomerModel>(
            MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
          );
          if (context.mounted && created != null) {
            Provider.of<CustomerProvider>(context, listen: false).fetchCustomers();
          }
        },
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18, color: Colors.white),
        label: const Text(
          'Add New Party',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: 0.3),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vyaparPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 4,
          shadowColor: AppColors.vyaparPink.withValues(alpha: 0.4),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const CreateInvoiceScreen()),
          );
        },
        icon: const Icon(Icons.add_circle_outline_rounded, size: 19, color: Colors.white),
        label: const Text(
          'Add New Sale',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: 0.3),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vyaparPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 4,
          shadowColor: AppColors.vyaparPink.withValues(alpha: 0.4),
        ),
      );
    }
  }
}
