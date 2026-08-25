import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/business_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/backend_sync_service.dart';
import 'business_profile_screen.dart';

class ManageCompaniesScreen extends StatefulWidget {
  const ManageCompaniesScreen({super.key});

  @override
  State<ManageCompaniesScreen> createState() => _ManageCompaniesScreenState();
}

class _ManageCompaniesScreenState extends State<ManageCompaniesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    HapticFeedback.lightImpact();
    final busP = context.read<BusinessProvider>();
    final custP = context.read<CustomerProvider>();
    final prodP = context.read<ProductProvider>();
    final invP = context.read<InvoiceProvider>();
    final authP = context.read<AuthProvider>();

    await BackendSyncService.instance.forceSync(
      authProvider: authP,
      businessProvider: busP,
      customerProvider: custP,
      productProvider: prodP,
      invoiceProvider: invP,
    );

    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Companies and billing data synchronized!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentBusiness = businessProvider.business;
    final companies = businessProvider.companies;
    final userPhone = authProvider.user?.phone.isNotEmpty == true
        ? authProvider.user!.phone
        : (currentBusiness.phone.isNotEmpty ? currentBusiness.phone : '9344920419');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Manage Companies',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _isRefreshing ? null : _handleRefresh,
            tooltip: 'Sync Companies',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'add') {
                _showAddCompanyDialog(context);
              } else if (val == 'restore') {
                _showRestoreBackupDialog(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'add',
                child: Row(
                  children: [
                    Icon(Icons.add_business_outlined, size: 20, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Text('Add New Company', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.restore_outlined, size: 20, color: Color(0xFFEA580C)),
                    SizedBox(width: 10),
                    Text('Restore Backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFDC2626),
              indicatorWeight: 3,
              labelColor: const Color(0xFFDC2626),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'My Companies'),
                Tab(text: 'Shared With Me'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── Tab 1: My Companies ──────────────────────────────────────────
          Column(
            children: [
              // User Account Info Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Currently logged in with:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userPhone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _confirmLogout(context, authProvider),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Companies List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  itemCount: companies.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final comp = companies[index];
                    final isCurrent = comp.id == currentBusiness.id ||
                        (comp.businessName.toLowerCase() == currentBusiness.businessName.toLowerCase());
                    return _buildCompanyCard(context, comp, isCurrent, businessProvider);
                  },
                ),
              ),
            ],
          ),

          // ─── Tab 2: Shared With Me ────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Shared Companies',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When another business owner shares access with your phone number, their company ledger will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ─── Bottom Sticky Action Bar ─────────────────────────────────────────
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Restore Backup Button
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  onPressed: () => _showRestoreBackupDialog(context),
                  icon: const Icon(Icons.restore_rounded, size: 18, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Restore\nbackup',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                      height: 1.1,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Add Company Button
              Expanded(
                flex: 7,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddCompanyDialog(context),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Add Company',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(
    BuildContext context,
    BusinessModel company,
    bool isCurrent,
    BusinessProvider businessProvider,
  ) {
    final phoneText = company.phone.isNotEmpty ? company.phone : '9344920419';
    final lastSaleText = company.lastSaleCreated.isNotEmpty
        ? 'Last Sale Created: ${company.lastSaleCreated}'
        : 'Last Sale Created: ${DateFormat('dd/MM/yyyy').format(DateTime.now())} at 06:07 am';

    return GestureDetector(
      onTap: () async {
        if (!isCurrent) {
          HapticFeedback.mediumImpact();
          await businessProvider.switchToCompany(company.id);
          // Refresh customer and invoice providers for new company
          if (context.mounted) {
            context.read<CustomerProvider>().fetchCustomers();
            context.read<InvoiceProvider>().fetchInvoices();
            context.read<ProductProvider>().fetchProducts();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to ${company.businessName}'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isCurrent ? 0.04 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top tag if current company
            if (isCurrent) ...[
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD97706),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Current Company',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Company Title and 3-dots Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    company.businessName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'switch') {
                      businessProvider.switchToCompany(company.id);
                    } else if (val == 'edit') {
                      businessProvider.switchToCompany(company.id);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                      );
                    } else if (val == 'delete') {
                      _confirmDeleteCompany(context, company, businessProvider);
                    } else if (val == 'sync') {
                      businessProvider.toggleCompanySync(company.id);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isCurrent)
                      const PopupMenuItem(
                        value: 'switch',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 10),
                            Text('Switch to Company'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF059669)),
                          SizedBox(width: 10),
                          Text('Edit Profile & Bank'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sync',
                      child: Row(
                        children: [
                          Icon(
                            company.syncOn ? Icons.sync_disabled : Icons.sync,
                            size: 18,
                            color: const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 10),
                          Text(company.syncOn ? 'Turn Sync OFF' : 'Turn Sync ON'),
                        ],
                      ),
                    ),
                    if (businessProvider.companies.length > 1)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Delete Company', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Phone Row
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  phoneText,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Last Sale Created
            Text(
              lastSaleText,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),

            const SizedBox(height: 10),

            // Sync Status Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: company.syncOn ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                company.syncOn ? 'SYNC ON' : 'SYNC OFF',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: company.syncOn ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Add Company Dialog ───────────────────────────────────────────────────

  void _showAddCompanyDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '9344920419');
    final gstinCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Kakinada');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Company',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Company / Business Name *',
                      hintText: 'e.g. BALAJI SEA FOODS',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: InputDecoration(
                            labelText: 'City',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gstinCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'GSTIN (Optional)',
                      hintText: '37AAAAA0000A1Z5',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter company name')),
                          );
                          return;
                        }
                        final newComp = BusinessModel(
                          id: 'comp_${DateTime.now().millisecondsSinceEpoch}',
                          businessName: name,
                          phone: phoneCtrl.text.trim(),
                          city: cityCtrl.text.trim(),
                          gstin: gstinCtrl.text.trim().toUpperCase(),
                          syncOn: true,
                          lastSaleCreated: '${DateFormat('dd/MM/yyyy').format(DateTime.now())} at ${DateFormat('hh:mm a').format(DateTime.now()).toLowerCase()}',
                        );
                        final busP = Provider.of<BusinessProvider>(context, listen: false);
                        await busP.addCompany(newComp);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Company "$name" created and activated!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Create & Activate Company', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Restore Backup Dialog ────────────────────────────────────────────────

  void _showRestoreBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Restore Backup'),
          ],
        ),
        content: const Text(
          'Would you like to restore billing data and companies from the cloud backup archive?',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _handleRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Restore Cloud Backup'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCompany(BuildContext context, BusinessModel company, BusinessProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${company.businessName}?'),
        content: const Text(
          'Are you sure you want to remove this company profile? Local invoices associated with this company will be unlinked.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteCompany(company.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Company ${company.businessName} deleted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of your billing account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
              auth.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
