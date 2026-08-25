import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/indian_states.dart';
import '../../models/business_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _logoController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;
  late TextEditingController _gstinController;
  late TextEditingController _panController;
  late TextEditingController _prefixController;
  late TextEditingController _nextNumberController;

  // Bank Details
  late TextEditingController _bankNameController;
  late TextEditingController _holderNameController;
  late TextEditingController _accountNoController;
  late TextEditingController _ifscController;
  late TextEditingController _branchController;
  late TextEditingController _upiController;

  late TextEditingController _termsController;

  bool _isUploadingLogo = false;

  String _selectedState = 'Andhra Pradesh';
  String _selectedStateCode = '37';

  @override
  void initState() {
    super.initState();
    final business = Provider.of<BusinessProvider>(context, listen: false).business;

    _nameController = TextEditingController(text: business.businessName);
    _logoController = TextEditingController(text: business.logo);
    _phoneController = TextEditingController(text: business.phone);
    _emailController = TextEditingController(text: business.email);
    _addressController = TextEditingController(text: business.address);
    _cityController = TextEditingController(text: business.city);
    _pincodeController = TextEditingController(text: business.pincode);
    _gstinController = TextEditingController(text: business.gstin);
    _panController = TextEditingController(text: business.pan);
    _prefixController = TextEditingController(text: business.invoicePrefix);
    _nextNumberController = TextEditingController(text: business.nextInvoiceNumber.toString());

    _bankNameController = TextEditingController(text: business.bankDetails.bankName);
    _holderNameController = TextEditingController(text: business.bankDetails.accountHolderName);
    _accountNoController = TextEditingController(text: business.bankDetails.accountNumber);
    _ifscController = TextEditingController(text: business.bankDetails.ifscCode);
    _branchController = TextEditingController(text: business.bankDetails.branch);
    _upiController = TextEditingController(text: business.bankDetails.upiId);

    _termsController = TextEditingController(text: business.termsAndConditions);

    _selectedState = business.state.isNotEmpty ? business.state : 'Andhra Pradesh';
    _selectedStateCode = business.stateCode.isNotEmpty ? business.stateCode : '37';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _prefixController.dispose();
    _nextNumberController.dispose();
    _bankNameController.dispose();
    _holderNameController.dispose();
    _accountNoController.dispose();
    _ifscController.dispose();
    _branchController.dispose();
    _upiController.dispose();
    _termsController.dispose();
    super.dispose();
  }
  /// Pick image from gallery and upload to Cloudinary, then save logo URL
  Future<void> _pickAndUploadLogo() async {
    // Capture ALL context-dependent refs before any await
    final invoiceProvider = context.read<InvoiceProvider>();

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);

    try {
      final url = await invoiceProvider.uploadAttachment(picked);
      if (url != null && mounted) {
        setState(() => _logoController.text = url);
        _saveProfile();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo upload failed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Widget _buildLogoUploadSection() {
    final logoUrl = _logoController.text.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Logo',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isUploadingLogo ? null : _pickAndUploadLogo,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    image: logoUrl.isNotEmpty && logoUrl.startsWith('http')
                        ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _isUploadingLogo
                      ? const Center(
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (logoUrl.isEmpty || !logoUrl.startsWith('http'))
                          ? const Icon(Icons.add_photo_alternate_outlined, size: 30, color: Color(0xFF94A3B8))
                          : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                        icon: Icon(
                          _isUploadingLogo ? Icons.hourglass_top_rounded : Icons.upload_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _isUploadingLogo
                              ? 'Uploading...'
                              : (logoUrl.isNotEmpty ? 'Change Logo' : 'Upload Logo'),
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (logoUrl.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _logoController.clear());
                            _saveProfile();
                          },
                          icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                          label: const Text(
                            'Remove Logo',
                            style: TextStyle(fontSize: 12, color: Colors.redAccent),
                          ),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'Shown on home screen & all PDF invoices',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final updated = provider.business.copyWith(
      businessName: _nameController.text.trim(),
      logo: _logoController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _selectedState,
      stateCode: _selectedStateCode,
      pincode: _pincodeController.text.trim(),
      gstin: _gstinController.text.trim().toUpperCase(),
      pan: _panController.text.trim().toUpperCase(),
      invoicePrefix: _prefixController.text.trim().toUpperCase(),
      nextInvoiceNumber: int.tryParse(_nextNumberController.text) ?? 1,
      bankDetails: BankDetails(
        bankName: _bankNameController.text.trim(),
        accountHolderName: _holderNameController.text.trim(),
        accountNumber: _accountNoController.text.trim(),
        ifscCode: _ifscController.text.trim().toUpperCase(),
        branch: _branchController.text.trim(),
        upiId: _upiController.text.trim(),
      ),
      termsAndConditions: _termsController.text.trim(),
    );

    final success = await provider.updateBusinessProfile(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Business profile updated successfully!' : 'Failed to update profile'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppColors.primary),
            onPressed: _saveProfile,
            tooltip: 'Save Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Basic Business Details
              _buildSectionCard(
                title: 'Business Information',
                icon: Icons.storefront_rounded,
                children: [
                  CustomTextField(
                    label: 'Business / Trade Name',
                    controller: _nameController,
                    isRequired: true,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Business name is required' : null,
                  ),
                  // ─── Logo Upload Section ─────────────────────────────────────────────────
                  _buildLogoUploadSection(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Contact Phone',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. GST & Tax Identifiers
              _buildSectionCard(
                title: 'GST & Tax Identifiers',
                icon: Icons.assignment_outlined,
                children: [
                  CustomDropdown<String>(
                    label: 'State (Place of Supply / Seller State)',
                    value: _selectedState,
                    isRequired: true,
                    items: IndianStates.all.map((s) {
                      return DropdownMenuItem<String>(
                        value: s.name,
                        child: Text('${s.name} (${s.code})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedState = val;
                          _selectedStateCode = IndianStates.getCodeByName(val);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: CustomTextField(
                          label: 'GSTIN (15 Digits)',
                          controller: _gstinController,
                          hintText: '37AAAAA0000A1Z5',
                          onChanged: (val) {
                            // If GSTIN starts with 2 digits, auto-suggest state code
                            if (val.length >= 2) {
                              final code = val.substring(0, 2);
                              final found = IndianStates.all.firstWhere(
                                (s) => s.code == code,
                                orElse: () => IndianStates.all.first,
                              );
                              if (found.code == code && _selectedState != found.name) {
                                setState(() {
                                  _selectedState = found.name;
                                  _selectedStateCode = found.code;
                                });
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CustomTextField(
                          label: 'PAN (10 Digits)',
                          controller: _panController,
                          hintText: 'AAAAA0000A',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Address / Street',
                    controller: _addressController,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'City',
                          controller: _cityController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'Pincode',
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. Invoice Number Sequence Settings
              _buildSectionCard(
                title: 'Invoice Numbering Settings',
                icon: Icons.format_list_numbered_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Invoice Prefix',
                          controller: _prefixController,
                          hintText: 'INV',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'Next Number',
                          controller: _nextNumberController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview: ${_prefixController.text.trim()}-${(_nextNumberController.text.trim()).padLeft(4, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. Bank & Payment Details
              _buildSectionCard(
                title: 'Bank & Payment Details (Printed on Invoice)',
                icon: Icons.account_balance_outlined,
                children: [
                  CustomTextField(
                    label: 'Bank Name',
                    controller: _bankNameController,
                    hintText: 'State Bank of India',
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Account Holder Name',
                    controller: _holderNameController,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Account Number',
                          controller: _accountNoController,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'IFSC Code',
                          controller: _ifscController,
                          hintText: 'SBIN0001234',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Branch Name',
                          controller: _branchController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'UPI ID / VPA',
                          controller: _upiController,
                          hintText: 'merchant@upi',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 5. Terms & Conditions
              _buildSectionCard(
                title: 'Terms & Conditions',
                icon: Icons.rule_folder_outlined,
                children: [
                  CustomTextField(
                    label: 'Default Invoice Terms & Conditions',
                    controller: _termsController,
                    maxLines: 4,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('SAVE BUSINESS PROFILE'),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
