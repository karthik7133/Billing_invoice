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
import '../../services/pdf_invoice_service.dart';
import '../../services/share_service.dart';
import '../business/business_profile_screen.dart';
import '../customers/add_edit_customer_screen.dart';
import '../customers/party_details_screen.dart';
import '../invoices/create_invoice_screen.dart';
import '../invoices/invoice_detail_screen.dart';
import '../invoices/invoice_pdf_preview_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0 = Transaction Details, 1 = Party Details
  int _selectedTab = 1; // Default to Party Details as in Image 1

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
    final custP = Provider.of<CustomerProvider>(context, listen: false);
    final invP = Provider.of<InvoiceProvider>(context, listen: false);
    final busP = Provider.of<BusinessProvider>(context, listen: false);

    await Future.wait([
      custP.fetchCustomers(),
      invP.fetchInvoices(),
      busP.fetchBusinessProfile(),
    ]);
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
        : 'JMJ SEA FOODS';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _buildTopHeader(context, businessName),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // 1. Top Segmented Pills (Transaction Details vs Party Details)
            _buildSegmentedTabSelector(),

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

  // ─── 1. Header (Logo, Title, Shield, Bell, Settings) ──────────────────────────
  PreferredSizeWidget _buildTopHeader(BuildContext context, String businessName) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leadingWidth: 44,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '🦀',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        businessName,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1E293B),
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shield_outlined, color: Color(0xFF64748B), size: 22),
          tooltip: 'Security Status',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 22),
          tooltip: 'Notifications',
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B), size: 22),
          tooltip: 'Settings / Business Profile',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const BusinessProfileScreen()),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── 2. Segmented Pill Tabs (Transaction Details vs Party Details) ─────────────
  Widget _buildSegmentedTabSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? AppColors.vyaparPinkLight : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _selectedTab == 0 ? AppColors.vyaparPink : const Color(0xFFE2E8F0),
                    width: _selectedTab == 0 ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedTab == 0 ? FontWeight.w800 : FontWeight.w500,
                      color: _selectedTab == 0 ? AppColors.vyaparPink : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? AppColors.vyaparPinkLight : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _selectedTab == 1 ? AppColors.vyaparPink : const Color(0xFFE2E8F0),
                    width: _selectedTab == 1 ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Party Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedTab == 1 ? FontWeight.w800 : FontWeight.w500,
                      color: _selectedTab == 1 ? AppColors.vyaparPink : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Quick Links Row (Images 1 & 2) ─────────────────────────────────────────
  Widget _buildQuickLinksRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Links',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _selectedTab == 1
                ? [
                    _buildQuickLinkItem(
                      icon: Icons.hub_outlined,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      label: 'Network',
                      onTap: () {},
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.receipt_long_outlined,
                      iconBg: const Color(0xFFE8F1FC),
                      iconColor: const Color(0xFF0284C7),
                      label: 'Party State...',
                      onTap: () {},
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.settings_outlined,
                      iconBg: const Color(0xFFF1F5F9),
                      iconColor: const Color(0xFF475569),
                      label: 'Party Settings',
                      onTap: () {},
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.arrow_forward_ios_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF3B82F6),
                      label: 'Show All',
                      onTap: () {},
                    ),
                  ]
                : [
                    _buildQuickLinkItem(
                      icon: Icons.note_add_outlined,
                      iconBg: const Color(0xFFFFECEF),
                      iconColor: AppColors.vyaparPink,
                      label: 'Add Txn',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                        );
                      },
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.analytics_outlined,
                      iconBg: const Color(0xFFE8F1FC),
                      iconColor: const Color(0xFF0284C7),
                      label: 'Sale Report',
                      onTap: () {},
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.settings_outlined,
                      iconBg: const Color(0xFFF1F5F9),
                      iconColor: const Color(0xFF475569),
                      label: 'Txn Settings',
                      onTap: () {},
                    ),
                    _buildQuickLinkItem(
                      icon: Icons.arrow_forward_ios_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF3B82F6),
                      label: 'Show All',
                      onTap: () {},
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
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  // ─── 4. Search & Filter Bar ───────────────────────────────────────────────────
  Widget _buildSearchBar() {
    final hint = _selectedTab == 1 ? 'Search any party' : 'Search for a transaction';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            IconButton(
              icon: const Icon(Icons.filter_alt_outlined, color: Color(0xFF2563EB), size: 20),
              onPressed: () {},
            ),
            if (_selectedTab == 1)
              IconButton(
                icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 20),
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
  }

  // ─── 5. Party Details List (Image 1) ──────────────────────────────────────────
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
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No parties matching "$_searchQuery"' : 'No Parties Added Yet',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Add New Party" below to add your first customer',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 80),
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
            : DateFormat('dd MMM, yy').format(DateTime.now());

        final isReceivable = calculatedBalance >= 0;
        final balanceAbs = calculatedBalance.abs();

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (c) => PartyDetailsScreen(customer: party)),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Party Name & Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                // Right: Amount & Status (You'll Get / You'll Give)
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
                    Text(
                      isReceivable
                          ? (balanceAbs > 0 ? "You'll Get" : 'Settled')
                          : "You'll Give",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isReceivable
                            ? (balanceAbs > 0 ? AppColors.receivableGreen : const Color(0xFF94A3B8))
                            : AppColors.payableRed,
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

  // ─── 6. Transaction Details List (Image 2) ────────────────────────────────────
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
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No transactions matching "$_searchQuery"' : 'No Transactions Yet',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Add New Sale" below to create a bill',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 80),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Customer Name | #No31 | Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        inv.customerSnapshot.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '#${inv.invoiceNumber}',
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
                const SizedBox(height: 6),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFE6F7F0) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPaid ? 'SALE : PAID' : 'SALE : UNPAID',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isPaid ? AppColors.receivableGreen : const Color(0xFFB45309),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Bottom Row: Total | Balance | Print / Share / 3 dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.format(inv.grandTotal),
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
                              CurrencyFormatter.format(inv.balanceDue),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: inv.balanceDue > 0 ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
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
                            final bytes = await PdfInvoiceService.generateTaxInvoicePdf(inv);
                            await ShareService.sharePdf(bytes, filename: 'Invoice_${inv.invoiceNumber}.pdf');
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

  // ─── 7. Floating Action Button (Images 1 & 2) ─────────────────────────────────
  Widget _buildFloatingActionButton(BuildContext context) {
    if (_selectedTab == 1) {
      // "+ Add New Party" pill FAB
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vyaparPink,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 6,
          shadowColor: AppColors.vyaparPink.withValues(alpha: 0.4),
        ),
      );
    } else {
      // "+ Add New Sale" pill FAB
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const CreateInvoiceScreen()),
          );
        },
        icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.white),
        label: const Text(
          'Add New Sale',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vyaparPink,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 6,
          shadowColor: AppColors.vyaparPink.withValues(alpha: 0.4),
        ),
      );
    }
  }
}
