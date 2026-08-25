import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/business_provider.dart';

class InvoicePrintSettingsScreen extends StatefulWidget {
  const InvoicePrintSettingsScreen({super.key});

  @override
  State<InvoicePrintSettingsScreen> createState() => _InvoicePrintSettingsScreenState();
}

class _InvoicePrintSettingsScreenState extends State<InvoicePrintSettingsScreen> {
  String _paperFormat = 'A4 Regular (Sales Bill)';
  bool _showCrabLogo = true;
  bool _showBankDetails = true;
  bool _showAmountInWords = true;
  bool _showSignature = true;
  late TextEditingController _termsController;

  @override
  void initState() {
    super.initState();
    final business = Provider.of<BusinessProvider>(context, listen: false).business;
    _termsController = TextEditingController(text: business.termsAndConditions);
  }

  @override
  void dispose() {
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Invoice Print & PDF Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('PRINT PAPER & LAYOUT'),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Default Paper Size', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                const Text('Choose standard PDF page layout', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _paperFormat,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  items: [
                    'A4 Regular (Sales Bill)',
                    'A5 Compact Sheet',
                    'Thermal Receipt (3 Inch / 80mm)',
                  ].map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13.5)))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _paperFormat = v);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _buildSectionHeader('PDF HEADER & BRANDING'),
          _buildSwitchTile(
            title: 'Include Crab Logo on Header',
            subtitle: 'Render circular Crab badge at the top-right of sales bill',
            value: _showCrabLogo,
            onChanged: (v) => setState(() => _showCrabLogo = v),
          ),
          _buildSwitchTile(
            title: 'Include Bank & UPI Info on Footer',
            subtitle: 'Display A/C Number, IFSC & UPI ID on invoice footer',
            value: _showBankDetails,
            onChanged: (v) => setState(() => _showBankDetails = v),
          ),
          _buildSwitchTile(
            title: 'Print Total Amount in Words',
            subtitle: 'Auto-convert final invoice grand total into spoken words',
            value: _showAmountInWords,
            onChanged: (v) => setState(() => _showAmountInWords = v),
          ),
          _buildSwitchTile(
            title: 'Include Authorized Signatory Block',
            subtitle: 'Show signature line at the bottom-right of PDF',
            value: _showSignature,
            onChanged: (v) => setState(() => _showSignature = v),
          ),

          const SizedBox(height: 16),
          _buildSectionHeader('TERMS & CONDITIONS FOOTER'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Terms Printed on Bill', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                TextField(
                  controller: _termsController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter business terms & conditions...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.lightImpact();
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              final current = businessProvider.business;
              await businessProvider.updateBusinessProfile(
                current.copyWith(termsAndConditions: _termsController.text.trim()),
              );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Invoice print settings saved!'),
                  backgroundColor: AppColors.success,
                ),
              );
              nav.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Print Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF2563EB),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
