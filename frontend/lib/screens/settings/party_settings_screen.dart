import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

class PartySettingsScreen extends StatefulWidget {
  const PartySettingsScreen({super.key});

  @override
  State<PartySettingsScreen> createState() => _PartySettingsScreenState();
}

class _PartySettingsScreenState extends State<PartySettingsScreen> {
  bool _enableCreditPeriod = true;
  int _defaultCreditDays = 15;
  bool _allowDuplicateInvoiceNo = true;
  bool _showOpeningBalanceInLedger = true;
  bool _autoSendPaymentReminder = false;
  bool _showPartyPhoneOnInvoice = true;

  @override
  Widget build(BuildContext context) {
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
          'Party Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('CREDIT & PAYMENT TERMS'),
          _buildSettingTile(
            title: 'Default Credit Period',
            subtitle: '$_defaultCreditDays days payment term for all new parties',
            trailing: DropdownButton<int>(
              value: _defaultCreditDays,
              underline: const SizedBox(),
              items: [7, 15, 30, 45, 60]
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d Days')))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _defaultCreditDays = val);
              },
            ),
          ),
          _buildSwitchTile(
            title: 'Enforce Credit Limit Warnings',
            subtitle: 'Alert when party outstanding exceeds allowed limit',
            value: _enableCreditPeriod,
            onChanged: (v) => setState(() => _enableCreditPeriod = v),
          ),
          _buildSwitchTile(
            title: 'Auto Payment Reminders',
            subtitle: 'Generate daily reminder alerts for overdue receivables',
            value: _autoSendPaymentReminder,
            onChanged: (v) => setState(() => _autoSendPaymentReminder = v),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('PARTY STATEMENT & INVOICE NUMBERING'),
          _buildSwitchTile(
            title: 'Allow Same Invoice No. Per Party',
            subtitle: 'Customer to customer allow editable/reusable sequence numbers',
            value: _allowDuplicateInvoiceNo,
            onChanged: (v) => setState(() => _allowDuplicateInvoiceNo = v),
          ),
          _buildSwitchTile(
            title: 'Include Opening Balance in Statement',
            subtitle: 'Show beginning balance row in ledger calculations',
            value: _showOpeningBalanceInLedger,
            onChanged: (v) => setState(() => _showOpeningBalanceInLedger = v),
          ),
          _buildSwitchTile(
            title: 'Show Party Phone & Address on Bill',
            subtitle: 'Display customer contact details under Bill To header',
            value: _showPartyPhoneOnInvoice,
            onChanged: (v) => setState(() => _showPartyPhoneOnInvoice = v),
          ),

          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Party settings saved successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Party Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
          trailing,
        ],
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
