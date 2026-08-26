import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../models/business_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/backend_sync_service.dart';
import '../../widgets/image_crop_dialog.dart';
import '../../main.dart' show mainNavigationKey;
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
        HapticFeedback.mediumImpact();
        // Switch to this company in state + cache
        await businessProvider.switchToCompany(company.id);

        if (!context.mounted) return;

        // Set companyId on providers BEFORE fetching so API calls are scoped correctly
        context.read<CustomerProvider>().setActiveCompany(company.id);
        context.read<InvoiceProvider>().setActiveCompany(company.id);

        // Refresh all providers with new company context
        context.read<CustomerProvider>().fetchCustomers();
        context.read<InvoiceProvider>().fetchInvoices();
        context.read<ProductProvider>().fetchProducts();

        // Jump the root bottom nav to the Home (Dashboard) tab
        mainNavigationKey.currentState?.switchToHomeTab();

        // Pop all pushed routes back to MainNavigationScreen (root)
        Navigator.of(context).popUntil((route) => route.isFirst);
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

            // Company Logo + Title and 3-dots Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Company Logo Thumbnail or Initial Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: company.logo.isNotEmpty ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    image: company.logo.isNotEmpty && (company.logo.startsWith('http') || company.logo.startsWith('data:image'))
                        ? DecorationImage(
                            image: NetworkImage(company.logo),
                            fit: BoxFit.contain,
                          )
                        : null,
                  ),
                  child: company.logo.isEmpty || (!company.logo.startsWith('http') && !company.logo.startsWith('data:image'))
                      ? Center(
                          child: Text(
                            company.businessName.isNotEmpty ? company.businessName[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.businessName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            phoneText,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) async {
                    if (val == 'switch') {
                      HapticFeedback.mediumImpact();
                      await businessProvider.switchToCompany(company.id);
                      if (!context.mounted) return;
                      context.read<CustomerProvider>().setActiveCompany(company.id);
                      context.read<InvoiceProvider>().setActiveCompany(company.id);
                      context.read<CustomerProvider>().fetchCustomers();
                      context.read<InvoiceProvider>().fetchInvoices();
                      context.read<ProductProvider>().fetchProducts();
                      mainNavigationKey.currentState?.switchToHomeTab();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    } else if (val == 'logo') {
                      _pickCropAndSaveCompanyLogo(context, company, businessProvider);
                    } else if (val == 'edit') {
                      await businessProvider.switchToCompany(company.id);
                      if (!context.mounted) return;
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
                      value: 'logo',
                      child: Row(
                        children: [
                          Icon(Icons.crop_rotate_rounded, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 10),
                          Text('Upload / Crop Logo'),
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

            const SizedBox(height: 8),

            const SizedBox(height: 4),

            // Last Sale Created
            Text(
              lastSaleText,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),

            const SizedBox(height: 10),

            // Sync Badge + Navigation Hint Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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

                // Tap hint
                Row(
                  children: [
                    Text(
                      isCurrent ? 'Go to Dashboard' : 'Tap to switch',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
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

  Future<void> _pickCropAndSaveCompanyLogo(
    BuildContext context,
    BusinessModel company,
    BusinessProvider businessProvider,
  ) async {
    final invoiceProvider = context.read<InvoiceProvider>();
    final croppedBytes = await ImageCropDialog.pickAndCrop(
      context,
      source: ImageSource.gallery,
      title: 'Crop Logo for ${company.businessName}',
    );

    if (croppedBytes == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Uploading cropped company logo...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    final url = await invoiceProvider.uploadAttachment(
      croppedBytes,
      filename: 'logo_${company.id}_${DateTime.now().millisecondsSinceEpoch}.png',
    );

    if (url != null && context.mounted) {
      await businessProvider.updateCompanyLogo(company.id, url);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logo updated for ${company.businessName}!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to upload logo. Please check connection.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ─── Add Company Dialog ───────────────────────────────────────────────────

  void _showAddCompanyDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '9344920419');
    final gstinCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Kakinada');
    String logoUrl = '';
    Uint8List? pendingLogoBytes;
    bool isUploadingLogo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(dialogCtx).viewInsets.bottom),
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
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Logo Picker Section
                    Row(
                      children: [
                        GestureDetector(
                          onTap: isUploadingLogo
                              ? null
                              : () async {
                                  final bytes = await ImageCropDialog.pickAndCrop(
                                    dialogCtx,
                                    source: ImageSource.gallery,
                                    title: 'Crop Logo for New Company',
                                  );
                                  if (bytes != null) {
                                    setModalState(() {
                                      pendingLogoBytes = bytes;
                                    });
                                  }
                                },
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              image: pendingLogoBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(pendingLogoBytes!),
                                      fit: BoxFit.contain,
                                    )
                                  : (logoUrl.isNotEmpty
                                      ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.contain)
                                      : null),
                            ),
                            child: pendingLogoBytes == null && logoUrl.isEmpty
                                ? const Center(
                                    child: Icon(Icons.add_a_photo_outlined, size: 22, color: Color(0xFF64748B)),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                onPressed: isUploadingLogo
                                    ? null
                                    : () async {
                                        final bytes = await ImageCropDialog.pickAndCrop(
                                          dialogCtx,
                                          source: ImageSource.gallery,
                                          title: 'Crop Logo for New Company',
                                        );
                                        if (bytes != null) {
                                          setModalState(() {
                                            pendingLogoBytes = bytes;
                                          });
                                        }
                                      },
                                icon: const Icon(Icons.crop_rotate_rounded, size: 16),
                                label: Text(
                                  pendingLogoBytes != null ? 'Change / Re-crop Logo' : 'Upload & Crop Logo',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  side: const BorderSide(color: Color(0xFF2563EB)),
                                  foregroundColor: const Color(0xFF2563EB),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Optional • Printed on all bills for this company',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: nameCtrl,
                      autofocus: false,
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
                        onPressed: isUploadingLogo
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter company name')),
                                  );
                                  return;
                                }

                                setModalState(() => isUploadingLogo = true);
                                final invP = context.read<InvoiceProvider>();
                                final busP = Provider.of<BusinessProvider>(context, listen: false);

                                // Upload pending logo if cropped
                                if (pendingLogoBytes != null) {
                                  final uploaded = await invP.uploadAttachment(
                                    pendingLogoBytes!,
                                    filename: 'company_logo_${DateTime.now().millisecondsSinceEpoch}.png',
                                  );
                                  if (uploaded != null) {
                                    logoUrl = uploaded;
                                  }
                                }

                                final newComp = BusinessModel(
                                  id: 'comp_${DateTime.now().millisecondsSinceEpoch}',
                                  businessName: name,
                                  logo: logoUrl,
                                  phone: phoneCtrl.text.trim(),
                                  city: cityCtrl.text.trim(),
                                  gstin: gstinCtrl.text.trim().toUpperCase(),
                                  syncOn: true,
                                  lastSaleCreated: '${DateFormat('dd/MM/yyyy').format(DateTime.now())} at ${DateFormat('hh:mm a').format(DateTime.now()).toLowerCase()}',
                                );
                                await busP.addCompany(newComp);
                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
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
                        child: isUploadingLogo
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 10),
                                  Text('Saving Company & Logo...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                ],
                              )
                            : const Text('Create & Activate Company', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
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
