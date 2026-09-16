import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';

import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import 'invoice_detail_screen.dart';
import '../../widgets/desktop_container.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final CustomerModel? preselectedCustomer;
  final InvoiceModel? existingInvoice;

  const CreateInvoiceScreen({super.key, this.preselectedCustomer, this.existingInvoice});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _SaleItemDraft {
  String? productId;
  String name;
  String description;
  String hsnSac;
  String unit;
  double quantity;
  double rate;
  double discount;
  String discountType; // 'PERCENT' or 'FIXED'
  double gstRate;

  _SaleItemDraft({
    this.productId,
    this.name = '',
    this.description = '',
    this.hsnSac = '',
    this.unit = 'Kg',
    this.quantity = 1.0,
    this.rate = 0.0,
    this.discount = 0.0,
    this.discountType = 'PERCENT',
    this.gstRate = 0.0,
  });

  double get subtotal => quantity * rate;
  double get discountAmount => discountType == 'PERCENT' ? (subtotal * discount / 100) : discount;
  double get taxableAmount => (subtotal - discountAmount).clamp(0.0, double.infinity);
  double get taxAmount => taxableAmount * (gstRate / 100);
  double get total => taxableAmount + taxAmount;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'description': description,
      'hsnSac': hsnSac,
      'unit': unit,
      'quantity': quantity,
      'rate': rate,
      'discount': discount,
      'discountType': discountType,
      'gstRate': gstRate,
    };
  }
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  CustomerModel? _selectedCustomer;
  late TextEditingController _customerNameController;
  late TextEditingController _billingNameController;
  late TextEditingController _phoneController;
  late TextEditingController _invoiceNoController;
  late TextEditingController _descriptionController;
  late TextEditingController _receivedAmountController;

  late DateTime _invoiceDate;
  String _selectedOrigin = 'AP';
  String _paymentType = 'Cash';
  bool _isReceivedChecked = false;
  bool _termsExpanded = false;
  String _termsAndConditions = '';
  bool _isSaving = false;
  String _savingStatusMessage = 'Saving Sale...';

  // Multiple payments list
  final List<PaymentRecord> _payments = [];

  // Origin dropdown options
  final List<String> _originOptions = [
    '-',
    'AP',
    'ORRISA',
    'GUJARAT',
    'KARNATAKA',
    'TAMIL NADU',
    'MAHARASHTRA',
    'WEST BENGAL',
    'KERALA',
  ];

  // Payment type options with IMPS
  final List<String> _paymentTypeOptions = [
    'Cash',
    'Bank Transfer',
    'UPI',
    'Cheque',
    'IMPS',
  ];

  // Invoice number prefix — 'NO' means no prefix
  String _invoicePrefix = 'NO';

  final List<_SaleItemDraft> _items = [];
  final List<PlatformFile> _attachedImages = [];

  // Tracks all item names + details ever entered — used for autocomplete suggestions
  final Map<String, _SaleItemDraft> _knownItemDetails = {};

  @override
  void initState() {
    super.initState();
    _invoiceDate = widget.existingInvoice?.invoiceDate ?? DateTime.now();
    _selectedOrigin = (widget.existingInvoice?.origin.isNotEmpty == true) ? widget.existingInvoice!.origin : 'AP';
    if (!_originOptions.contains(_selectedOrigin) && _selectedOrigin.isNotEmpty) {
      _originOptions.add(_selectedOrigin);
    }

    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final business = businessProvider.business;
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    // Auto-increment: find the next unused integer invoice number
    String defaultInvoiceNo;
    if (widget.existingInvoice != null) {
      defaultInvoiceNo = widget.existingInvoice!.invoiceNumber;
    } else {
      // Collect all numeric-looking invoice numbers already used
      final usedNumbers = <int>{};
      for (final inv in invoiceProvider.allInvoices) {
        final raw = inv.invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '');
        final n = int.tryParse(raw);
        if (n != null) usedNumbers.add(n);
      }
      // Find next number starting from max+1 or business default
      int next = business.nextInvoiceNumber > 0 ? business.nextInvoiceNumber : 1;
      while (usedNumbers.contains(next)) {
        next++;
      }
      defaultInvoiceNo = '$next';
    }

    _invoiceNoController = TextEditingController(text: defaultInvoiceNo);
    _descriptionController = TextEditingController(text: widget.existingInvoice?.description ?? '');
    _termsAndConditions = widget.existingInvoice?.termsAndConditions ?? business.termsAndConditions;

    if (widget.existingInvoice != null) {
      _selectedCustomer = widget.existingInvoice!.customerSnapshot;
      _customerNameController = TextEditingController(text: _selectedCustomer?.name ?? '');
      _billingNameController = TextEditingController(text: _selectedCustomer?.billingName ?? '');
      _phoneController = TextEditingController(text: _selectedCustomer?.phone ?? '');

      for (final it in widget.existingInvoice!.items) {
        final draft = _SaleItemDraft(
          productId: it.productId,
          name: it.name,
          description: it.description,
          hsnSac: it.hsnSac,
          unit: it.unit,
          quantity: it.quantity,
          rate: it.rate,
          discount: it.discount,
          discountType: it.discountType,
          gstRate: it.gstRate,
        );
        _items.add(draft);
        // Pre-populate autocomplete map from existing invoice items
        if (it.name.trim().isNotEmpty) {
          _knownItemDetails[it.name.trim().toLowerCase()] = draft;
        }
      }
      if (widget.existingInvoice!.payments.isNotEmpty) {
        _payments.addAll(widget.existingInvoice!.payments);
      } else if (widget.existingInvoice!.amountPaid > 0) {
        _payments.add(PaymentRecord(
          amount: widget.existingInvoice!.amountPaid,
          type: widget.existingInvoice!.paymentType.isNotEmpty ? widget.existingInvoice!.paymentType : 'Cash',
          date: widget.existingInvoice!.invoiceDate,
        ));
      }
      _isReceivedChecked = _payments.isNotEmpty;
      _paymentType = widget.existingInvoice!.paymentType.isNotEmpty ? widget.existingInvoice!.paymentType : 'Cash';
      if (!_paymentTypeOptions.contains(_paymentType) && _paymentType.isNotEmpty) {
        _paymentTypeOptions.add(_paymentType);
      }
      final totalPaid = _payments.fold<double>(0.0, (s, p) => s + p.amount);
      _receivedAmountController = TextEditingController(
        text: totalPaid > 0 ? totalPaid.toStringAsFixed(2) : '',
      );
    } else if (widget.preselectedCustomer != null) {
      _selectedCustomer = widget.preselectedCustomer;
      _customerNameController = TextEditingController(text: _selectedCustomer!.name);
      _billingNameController = TextEditingController(
        text: _selectedCustomer!.billingName.isNotEmpty ? _selectedCustomer!.billingName : _selectedCustomer!.name,
      );
      _phoneController = TextEditingController(text: _selectedCustomer!.phone);
      _receivedAmountController = TextEditingController(text: '');
    } else {
      // Clean, dynamic state with no dummy/static text
      _selectedCustomer = null;
      _customerNameController = TextEditingController(text: '');
      _billingNameController = TextEditingController(text: '');
      _phoneController = TextEditingController(text: '');
      _receivedAmountController = TextEditingController(text: '');
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _billingNameController.dispose();
    _phoneController.dispose();
    _invoiceNoController.dispose();
    _descriptionController.dispose();
    _receivedAmountController.dispose();
    super.dispose();
  }

  double _computeTotal() {
    return _items.fold<double>(0.0, (sum, it) => sum + it.total);
  }

  double _computeTotalDiscount() {
    return _items.fold<double>(0.0, (sum, it) => sum + it.discountAmount);
  }

  double _computeTotalTax() {
    return _items.fold<double>(0.0, (sum, it) => sum + it.taxAmount);
  }

  void _onCustomerSelected(CustomerModel customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer.name;
      _billingNameController.text = customer.billingName.isNotEmpty ? customer.billingName : customer.name;
      _phoneController.text = customer.phone;
    });
  }

  Future<void> _pickImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: 'Attach Photo / Receipt',
      );
      if (files.isNotEmpty) {
        setState(() {
          _attachedImages.addAll(files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    _pickImage();
  }

  void _showImagePreviewDialog(PlatformFile file, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: file.path != null
                      ? Image.file(File(file.path!), fit: BoxFit.contain, height: 320)
                      : const SizedBox(height: 320),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 16,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Photo #${index + 1}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                    onPressed: () {
                      setState(() => _attachedImages.removeAt(index));
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Invoice Number helpers ───────────────────────────────────────────────

  String _buildDisplayInvoiceNo() {
    final num = _invoiceNoController.text.trim();
    if (_invoicePrefix == 'NO' || _invoicePrefix.isEmpty) {
      return num.isEmpty ? '–' : num;
    }
    return num.isEmpty ? _invoicePrefix : '$_invoicePrefix-$num';
  }

  String _buildFinalInvoiceNo() {
    final num = _invoiceNoController.text.trim();
    if (_invoicePrefix == 'NO' || _invoicePrefix.isEmpty) {
      return num;
    }
    return num.isEmpty ? _invoicePrefix : '$_invoicePrefix-$num';
  }

  void _showInvoiceNumberSheet() {
    HapticFeedback.lightImpact();

    final List<String> prefixOptions = ['NO', 'N', 'AP', 'ORS', 'ORS/LT', 'INV', 'BILL', 'GEN'];
    String tempPrefix = _invoicePrefix;
    final tempNumberCtrl = TextEditingController(text: _invoiceNoController.text);
    final customPrefixCtrl = TextEditingController();
    bool showingCustomInput = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          // Live preview of how number will look
          final previewNum = tempNumberCtrl.text.trim();
          final preview = (tempPrefix == 'NO' || tempPrefix.isEmpty)
              ? (previewNum.isEmpty ? '–' : previewNum)
              : (previewNum.isEmpty ? tempPrefix : '$tempPrefix-$previewNum');

          return Padding(
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
                      // Handle
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Invoice Number',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Live Preview Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_outlined, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 10),
                            const Text(
                              'Preview: ',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            Text(
                              preview,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E3A8A),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Prefix section
                      const Text(
                        'Invoice Prefix',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 8),

                      // Prefix chips — wrap style
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...prefixOptions.map((opt) {
                            final isSelected = tempPrefix == opt;
                            return GestureDetector(
                              onTap: () => setSheet(() {
                                tempPrefix = opt;
                                showingCustomInput = false;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
                                    width: isSelected ? 0 : 1,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ] : null,
                                ),
                                child: Text(
                                  opt == 'NO' ? 'None' : opt,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            );
                          }),
                          // "+ Custom" chip
                          GestureDetector(
                            onTap: () => setSheet(() => showingCustomInput = !showingCustomInput),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: showingCustomInput ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: showingCustomInput ? const Color(0xFFEA580C) : const Color(0xFFD1D5DB),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 14,
                                    color: showingCustomInput ? const Color(0xFFEA580C) : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Custom',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: showingCustomInput ? const Color(0xFFEA580C) : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Custom prefix input (shows inline when + Custom tapped)
                      if (showingCustomInput) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customPrefixCtrl,
                                autofocus: true,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  hintText: 'e.g. INV, BILL, TN...',
                                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final custom = customPrefixCtrl.text.trim().toUpperCase();
                                if (custom.isNotEmpty) {
                                  setSheet(() {
                                    if (!prefixOptions.contains(custom)) {
                                      prefixOptions.add(custom);
                                    }
                                    tempPrefix = custom;
                                    showingCustomInput = false;
                                    customPrefixCtrl.clear();
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Invoice Number field — clean flat style
                      const Text(
                        'Invoice Number',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tempNumberCtrl,
                        keyboardType: TextInputType.text,
                        onChanged: (_) => setSheet(() {}), // trigger live preview
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '101',
                          hintStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFFCBD5E1),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                          ),
                          suffixIcon: tempNumberCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () => setSheet(() => tempNumberCtrl.clear()),
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _invoicePrefix = tempPrefix;
                              _invoiceNoController.text = tempNumberCtrl.text.trim();
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Invoice Number',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCustomOriginDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Enter Custom Origin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Origin / State',
            hintText: 'e.g. TELANGANA, ODISHA, etc.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5)),
            onPressed: () {
              final text = controller.text.trim().toUpperCase();
              if (text.isNotEmpty) {
                setState(() {
                  if (!_originOptions.contains(text)) {
                    _originOptions.add(text);
                  }
                  _selectedOrigin = text;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set Origin'),
          ),
        ],
      ),
    );
  }

  void _showCustomPaymentTypeDialog({void Function(String)? onAdded}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add Payment Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Payment Mode',
            hintText: 'e.g. RTGS, NEFT, Card, IMPS...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5)),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  if (!_paymentTypeOptions.contains(text)) {
                    _paymentTypeOptions.add(text);
                  }
                  _paymentType = text;
                });
                if (onAdded != null) onAdded(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add Type'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditPaymentDialog({int? index}) {
    HapticFeedback.lightImpact();
    final isEdit = index != null;
    final existing = isEdit ? _payments[index] : null;
    final grandTotal = _computeTotal();
    final currentReceived = _payments.fold<double>(0.0, (s, p) => s + p.amount);
    final remainingDue = (grandTotal - currentReceived).clamp(0.0, double.infinity);

    final amountCtrl = TextEditingController(
      text: existing != null
          ? (existing.amount == existing.amount.roundToDouble()
              ? existing.amount.toInt().toString()
              : existing.amount.toStringAsFixed(2))
          : (remainingDue > 0
              ? (remainingDue == remainingDue.roundToDouble()
                  ? remainingDue.toInt().toString()
                  : remainingDue.toStringAsFixed(2))
              : ''),
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime pickedDate = existing?.date ?? DateTime.now();
    String pickedType = existing?.type ?? _paymentType;

    if (!_paymentTypeOptions.contains(pickedType)) {
      _paymentTypeOptions.add(pickedType);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Payment' : 'Add Payment Received',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Amount Input
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Payment Amount (₹) *',
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              // Date & Payment Type Row
              Row(
                children: [
                  // Date picker
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: pickedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => pickedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(pickedDate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Payment Type dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _paymentTypeOptions.contains(pickedType) ? pickedType : 'Cash',
                          isExpanded: true,
                          items: [
                            ..._paymentTypeOptions.map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                type == 'IMPS'
                                    ? '⚡ IMPS'
                                    : (type == 'Cash'
                                        ? '💵 Cash'
                                        : (type == 'UPI'
                                            ? '📱 UPI'
                                            : (type == 'Bank Transfer'
                                                ? '🏦 Bank'
                                                : (type == 'Cheque' ? '📝 Cheque' : '💳 $type')))),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            )),
                            const DropdownMenuItem(
                              value: '__custom__',
                              child: Text('+ New Type...', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == '__custom__') {
                              _showCustomPaymentTypeDialog(onAdded: (newType) {
                                setModalState(() => pickedType = newType);
                              });
                            } else if (val != null) {
                              setModalState(() => pickedType = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Notes / Ref No
              TextField(
                controller: notesCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Notes / Reference (Optional)',
                  hintText: 'e.g. IMPS ref, Cheque no, Txn ID...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (amt <= 0) return;

                    final record = PaymentRecord(
                      id: existing?.id,
                      amount: amt,
                      type: pickedType,
                      date: pickedDate,
                      notes: notesCtrl.text.trim(),
                    );

                    setState(() {
                      if (isEdit) {
                        _payments[index] = record;
                      } else {
                        _payments.add(record);
                      }
                      _isReceivedChecked = _payments.isNotEmpty;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    isEdit ? 'Update Payment' : 'Add Payment',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveSale() async {
    if (_isSaving) return;

    final name = _customerNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatusMessage = 'Verifying sale details...';
    });

    try {
      final custProvider = Provider.of<CustomerProvider>(context, listen: false);
      final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
      final busProvider = Provider.of<BusinessProvider>(context, listen: false);
      final prodProvider = Provider.of<ProductProvider>(context, listen: false);

      CustomerModel customer;
      if (_selectedCustomer != null && _selectedCustomer!.name.toLowerCase() == name.toLowerCase()) {
        customer = _selectedCustomer!;
      } else {
        // Find or create customer dynamically
        final existing = custProvider.findByName(name);
        if (existing != null) {
          customer = existing;
        } else {
          setState(() => _savingStatusMessage = 'Adding new customer...');
          final newCust = CustomerModel(
            id: '',
            name: name,
            billingName: _billingNameController.text.trim(),
            phone: _phoneController.text.trim(),
            state: busProvider.business.state.isNotEmpty ? busProvider.business.state : 'Andhra Pradesh',
          );
          customer = (await custProvider.addCustomer(newCust)) ?? newCust;
        }
      }

      // ── Duplicate invoice number check per customer ───────────────────────
      final finalInvoiceNo = _buildFinalInvoiceNo();
      final isEditing = widget.existingInvoice != null;
      final duplicate = invProvider.allInvoices.any((inv) {
        final sameNum = inv.invoiceNumber.trim().toLowerCase() == finalInvoiceNo.trim().toLowerCase();
        final sameCust = inv.customerId == customer.id ||
            inv.customerSnapshot.name.toLowerCase() == customer.name.toLowerCase();
        // When editing, exclude the current invoice from the check
        final isSelf = isEditing && inv.invoiceNumber == widget.existingInvoice!.invoiceNumber;
        return sameNum && sameCust && !isSelf;
      });

      if (duplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invoice #$finalInvoiceNo already exists for ${customer.name}. Please use a different number.',
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      // ─────────────────────────────────────────────────────────────────────

      final rawItems = _items.map((it) => it.toMap()).toList();
      final totalRec = _payments.fold<double>(0.0, (s, p) => s + p.amount);
      final receivedInput = double.tryParse(_receivedAmountController.text.trim()) ?? 0.0;
      final amountPaid = _payments.isNotEmpty ? totalRec : (_isReceivedChecked ? receivedInput : 0.0);
      final finalPayments = _payments.isNotEmpty
          ? _payments
          : (amountPaid > 0
              ? [PaymentRecord(amount: amountPaid, type: _paymentType, date: _invoiceDate)]
              : <PaymentRecord>[]);

      // Upload attached images to Cloudinary
      final uploadedUrls = <String>[];
      if (_attachedImages.isNotEmpty) {
        setState(() => _savingStatusMessage = 'Uploading attached photos...');
        for (final img in _attachedImages) {
          final url = await invProvider.uploadAttachment(img);
          if (url != null && url.isNotEmpty) {
            uploadedUrls.add(url);
          }
        }
      }

      setState(() => _savingStatusMessage = isEditing ? 'Updating invoice...' : 'Saving invoice...');
      InvoiceModel invoice;
      try {
        if (isEditing) {
          invoice = await invProvider.updateInvoice(
            invoiceId: widget.existingInvoice!.id,
            customer: customer,
            business: busProvider.business,
            rawItems: rawItems,
            invoiceNumber: finalInvoiceNo,
            invoiceDate: _invoiceDate,
            origin: _selectedOrigin == '-' ? '' : _selectedOrigin,
            attachments: uploadedUrls.isNotEmpty ? uploadedUrls : widget.existingInvoice!.attachments,
            amountPaid: amountPaid,
            payments: finalPayments,
            paymentType: finalPayments.isNotEmpty ? finalPayments.first.type : _paymentType,
            description: _descriptionController.text.trim(),
            termsAndConditions: _termsAndConditions,
          );
        } else {
          invoice = await invProvider.createInvoice(
            customer: customer,
            business: busProvider.business,
            rawItems: rawItems,
            invoiceNumber: finalInvoiceNo,
            invoiceDate: _invoiceDate,
            origin: _selectedOrigin == '-' ? '' : _selectedOrigin,
            attachments: uploadedUrls,
            amountPaid: amountPaid,
            payments: finalPayments,
            paymentType: finalPayments.isNotEmpty ? finalPayments.first.type : _paymentType,
            description: _descriptionController.text.trim(),
            termsAndConditions: _termsAndConditions,
          );
        }
      } catch (e) {
        // Handle duplicate invoice number error (409 from backend)
        if (mounted) {
          final msg = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() => _savingStatusMessage = 'Updating records...');
      // Refresh customers and sync items concurrently to reduce perceived latency
      try {
        await Future.wait([
          custProvider.fetchCustomers(),
          prodProvider.syncItemsFromInvoices([invoice]),
        ]);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Sale #${invoice.invoiceNumber} updated successfully'
                : 'Sale #${invoice.invoiceNumber} saved successfully'),
            backgroundColor: AppColors.receivableGreen,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (ctx) => InvoiceDetailScreen(invoice: invoice)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _computeTotal();
    final totalDiscount = _computeTotalDiscount();
    final totalTax = _computeTotalTax();
    final totalPaymentsSum = _payments.fold<double>(0.0, (s, p) => s + p.amount);
    final receivedInput = double.tryParse(_receivedAmountController.text.trim()) ?? 0.0;
    final amountPaid = _payments.isNotEmpty ? totalPaymentsSum : (_isReceivedChecked ? receivedInput : 0.0);
    final balanceDue = (grandTotal - amountPaid).clamp(0.0, double.infinity);
    final overMoney = amountPaid > grandTotal ? amountPaid - grandTotal : 0.0;

    final customerProvider = Provider.of<CustomerProvider>(context);
    final hasSelectedCustomer = _selectedCustomer != null;
    final partyBalance = _selectedCustomer?.balance ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.existingInvoice != null ? 'Edit Sale #${widget.existingInvoice!.invoiceNumber}' : 'Sale',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        actions: [
          if (_items.isNotEmpty || _customerNameController.text.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _items.clear();
                  _customerNameController.clear();
                  _billingNameController.clear();
                  _phoneController.clear();
                  _descriptionController.clear();
                  _receivedAmountController.clear();
                  _attachedImages.clear();
                  _selectedCustomer = null;
                });
              },
              child: const Text('Clear', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          DesktopContainer(
            maxWidth: 1050,
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Invoice No, Date & Origin Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Invoice No (Tappable → opens prefix+number sheet)
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      onTap: () => _showInvoiceNumberSheet(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Invoice No.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _buildDisplayInvoiceNo(),
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),

                  // Date
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _invoiceDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _invoiceDate = picked);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yy').format(_invoiceDate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                              const Icon(Icons.calendar_today_outlined, color: Color(0xFF2563EB), size: 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),

                  // Origin (State)
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Origin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            GestureDetector(
                              onTap: _showCustomOriginDialog,
                              child: const Text('+ Custom', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _originOptions.contains(_selectedOrigin) ? _selectedOrigin : _originOptions.first,
                            isDense: true,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB), size: 18),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            items: [
                              ..._originOptions.map((orig) => DropdownMenuItem(
                                value: orig,
                                child: Text(
                                  orig == '-' ? '- (None)' : orig,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: orig == '-' ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                  ),
                                ),
                              )),
                              const DropdownMenuItem(
                                value: '__CUSTOM_ORIGIN__',
                                child: Text('+ Custom...', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == '__CUSTOM_ORIGIN__') {
                                _showCustomOriginDialog();
                              } else if (val != null) {
                                setState(() => _selectedOrigin = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Customer Section (Customer Name *, Billing Name, Phone)
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
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customerNameController,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                decoration: InputDecoration(
                                  labelText: 'Customer Name *',
                                  hintText: 'Enter customer or select party',
                                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                onChanged: (val) {
                                  final match = customerProvider.findByName(val);
                                  setState(() {
                                    _selectedCustomer = match;
                                  });
                                },
                              ),
                            ),
                            if (customerProvider.customers.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              PopupMenuButton<CustomerModel>(
                                icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF2563EB)),
                                tooltip: 'Select Existing Party',
                                onSelected: _onCustomerSelected,
                                itemBuilder: (_) => customerProvider.customers.map((c) {
                                  return PopupMenuItem(
                                    value: c,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 8),
                                        Text(
                                          CurrencyFormatter.format(c.balance),
                                          style: const TextStyle(fontSize: 12, color: AppColors.receivableGreen),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasSelectedCustomer)
                        Positioned(
                          top: 0,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            color: Colors.white,
                            child: Text(
                              'Party Balance: ${CurrencyFormatter.format(partyBalance)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.receivableGreen,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Billing Name
                  TextField(
                    controller: _billingNameController,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      labelText: 'Billing Name (Optional)',
                      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Phone Number
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Billed Items Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFBFDBFE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Color(0xFF1E88E5)),
                      SizedBox(width: 6),
                      Text(
                        'Billed Items',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                  Text(
                    '${_items.length} ${_items.length == 1 ? "Item" : "Items"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 4. Item Cards List
            if (_items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'No Items Added',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap below to add items, quantity, and rate to this sale',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final item = _items[index];
                  return _buildItemCard(item, index);
                },
              ),
              const SizedBox(height: 8),
              // Total Disc & Tax Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Disc: ${CurrencyFormatter.format(totalDiscount)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Text(
                      'Total Tax: ${CurrencyFormatter.format(totalTax)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // "+ Add Items" Button
            OutlinedButton.icon(
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add_circle, color: Color(0xFF1E88E5), size: 20),
              label: const Text(
                'Add Items',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E88E5)),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 14),

            // 5. Totals & Payment Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        CurrencyFormatter.format(grandTotal),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),

                  // Payments Received section
                  if (_payments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PAYMENTS RECEIVED (${_payments.length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        Text(
                          CurrencyFormatter.format(totalPaymentsSum),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
                      itemBuilder: (ctx, idx) {
                        final p = _payments[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              // Amount
                              Text(
                                CurrencyFormatter.format(p.amount),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 10),
                              // Type badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  p.type,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Date
                              Text(
                                DateFormat('dd MMM').format(p.date),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              // Edit button
                              InkWell(
                                onTap: () => _showAddOrEditPaymentDialog(index: idx),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Delete button
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _payments.removeAt(idx);
                                    _isReceivedChecked = _payments.isNotEmpty;
                                    final sum = _payments.fold<double>(0.0, (s, item) => s + item.amount);
                                    _receivedAmountController.text = sum > 0 ? sum.toStringAsFixed(2) : '';
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 10),
                  // "+ Add Payment" button
                  InkWell(
                    onTap: () => _showAddOrEditPaymentDialog(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF1E88E5)),
                          SizedBox(width: 6),
                          Text(
                            '+ Add Payment',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E88E5)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Received row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (_payments.isEmpty)
                            Checkbox(
                              value: _isReceivedChecked,
                              activeColor: const Color(0xFF1E88E5),
                              onChanged: (val) {
                                setState(() {
                                  _isReceivedChecked = val ?? false;
                                  if (_isReceivedChecked && _receivedAmountController.text.isEmpty) {
                                    _receivedAmountController.text = grandTotal > 0 ? grandTotal.toStringAsFixed(2) : '';
                                  }
                                });
                              },
                            ),
                          const Text(
                            'Received',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ],
                      ),
                      if (_payments.isNotEmpty)
                        Text(
                          CurrencyFormatter.format(amountPaid),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        )
                      else
                        Row(
                          children: [
                            const Text('₹ ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: _receivedAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                enabled: _isReceivedChecked,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  isDense: true,
                                  border: UnderlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Balance Due
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Balance Due',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.receivableGreen),
                      ),
                      Text(
                        CurrencyFormatter.format(balanceDue),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.receivableGreen),
                      ),
                    ],
                  ),

                  // O/D Banner
                  if (overMoney > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 6),
                              Text(
                                'O/D',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.format(overMoney),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Payment Type Selector + Add Payment Type button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Type', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _paymentTypeOptions.contains(_paymentType) ? _paymentType : _paymentTypeOptions.first,
                            isDense: true,
                            items: [
                              ..._paymentTypeOptions.map((type) {
                                String icon = '💵';
                                if (type.toLowerCase().contains('bank')) {
                                  icon = '🏦';
                                } else if (type.toLowerCase().contains('upi')) {
                                  icon = '📱';
                                } else if (type.toLowerCase().contains('cheque')) {
                                  icon = '📝';
                                } else if (type.toLowerCase().contains('imps')) {
                                  icon = '⚡';
                                } else {
                                  icon = '💳';
                                }
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text('$icon $type'),
                                );
                              }),
                              const DropdownMenuItem(
                                value: '__CUSTOM_TYPE__',
                                child: Text('+ Add Type...', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                              ),
                            ],
                            onChanged: (val) {
                              if (val == '__CUSTOM_TYPE__') {
                                _showCustomPaymentTypeDialog();
                              } else if (val != null) {
                                setState(() => _paymentType = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showCustomPaymentTypeDialog(),
                    child: const Text(
                      '+ Add Payment Type',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E88E5)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 6. Description & Dynamic Image / Photo Attachment
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descriptionController,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            labelText: 'Description / Notes',
                            hintText: 'Add remarks, payment notes, transport details...',
                            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Real interactive Image picker card
                      InkWell(
                        onTap: _showImageSourceSheet,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: Color(0xFF2563EB), size: 22),
                              SizedBox(height: 3),
                              Text('Add Photo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Display Attached Images Gallery
                  if (_attachedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Attached Photos & Receipts:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _attachedImages.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (ctx, idx) {
                          final img = _attachedImages[idx];
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () => _showImagePreviewDialog(img, idx),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 74,
                                    height: 74,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: img.path != null
                                        ? Image.file(File(img.path!), fit: BoxFit.cover)
                                        : const Icon(Icons.image_not_supported_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _attachedImages.removeAt(idx));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 7. Terms & Conditions Accordion
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                title: const Text(
                  'Terms & Conditions',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                initiallyExpanded: _termsExpanded,
                onExpansionChanged: (val) => setState(() => _termsExpanded = val),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
                    child: TextFormField(
                      initialValue: _termsAndConditions,
                      maxLines: 2,
                      onChanged: (v) => _termsAndConditions = v,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 1. Goods once sold cannot be returned.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      ),
      if (_isSaving) _buildSavingOverlay(),
    ],
  ),

      // 8. Bottom Bar: DesktopActionBar (Adapts between mobile full-width and desktop right-aligned)
      bottomNavigationBar: DesktopActionBar(
        maxDesktopWidth: 1050,
        secondaryButton: OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ),
        primaryButton: ElevatedButton(
          onPressed: _isSaving ? null : _saveSale,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5), // Vibrant blue Save button
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
          child: _isSaving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.existingInvoice != null ? 'Updating Sale...' : 'Saving Sale...',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                )
              : Text(
                  widget.existingInvoice != null ? 'Update Sale' : 'Save Sale',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _savingStatusMessage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Please wait while we record the transaction',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(_SaleItemDraft item, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Title & Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              Text(
                CurrencyFormatter.format(item.total),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subtotal Calculation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Item Subtotal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(
                '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.unit} x ${CurrencyFormatter.format(item.rate)} = ${CurrencyFormatter.format(item.subtotal)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
          if (item.discount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount (${item.discountType == "PERCENT" ? "%" : "₹"}): ${item.discount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFE59819)),
                ),
                Text(
                  '- ${CurrencyFormatter.format(item.discountAmount)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFE59819)),
                ),
              ],
            ),
          ],
          if (item.gstRate > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tax : ${item.gstRate.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                Text(
                  CurrencyFormatter.format(item.taxAmount),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          // Actions: Delete & Edit
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => _items.removeAt(index));
                },
                child: const Text('Delete', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _showEditItemDialog(item, index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    _showEditItemDialog(
      _SaleItemDraft(name: '', unit: 'Kg', quantity: 1, rate: 0, discount: 0, gstRate: 0),
      -1,
    );
  }

  void _showEditItemDialog(_SaleItemDraft draft, int index) {
    final qtyCtrl = TextEditingController(
      text: draft.quantity > 0 ? draft.quantity.toStringAsFixed(draft.quantity.truncateToDouble() == draft.quantity ? 0 : 2) : '1',
    );
    final rateCtrl = TextEditingController(
      text: draft.rate > 0 ? draft.rate.toStringAsFixed(draft.rate.truncateToDouble() == draft.rate ? 0 : 2) : '',
    );
    final unitCtrl = TextEditingController(text: draft.unit);
    final discCtrl = TextEditingController(text: draft.discount > 0 ? draft.discount.toStringAsFixed(0) : '0');
    // For autocomplete
    final nameTextCtrl = TextEditingController(text: draft.name);
    final nameFocusNode = FocusNode();

    // Build global item name suggestions from Product Catalog + ALL invoices + session
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final Set<String> globalItemNames = {};
    final Map<String, _SaleItemDraft> globalItemDetails = {};

    // 1. From Product & Service Catalog
    for (final p in productProvider.products) {
      final key = p.name.trim().toLowerCase();
      if (key.isNotEmpty) {
        globalItemNames.add(key);
        globalItemDetails[key] = _SaleItemDraft(
          name: p.name.trim(),
          unit: p.unit.isNotEmpty ? p.unit : 'Kg',
          rate: p.price,
          discount: 0,
          discountType: 'PERCENT',
          gstRate: 0,
        );
      }
    }

    // 2. From all past invoices
    for (final inv in invoiceProvider.allInvoices) {
      for (final it in inv.items) {
        final key = it.name.trim().toLowerCase();
        if (key.isNotEmpty && !globalItemNames.contains(key)) {
          globalItemNames.add(key);
          globalItemDetails[key] = _SaleItemDraft(
            name: it.name.trim(),
            unit: it.unit,
            rate: it.rate,
            discount: it.discount,
            discountType: it.discountType,
            gstRate: it.gstRate,
          );
        }
      }
    }
    // 3. Also merge locally tracked items (for current session items)
    for (final entry in _knownItemDetails.entries) {
      globalItemDetails.putIfAbsent(entry.key, () => entry.value);
      globalItemNames.add(entry.key);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Helper to auto-fill from global item details
          void applyKnownItem(String name) {
            final key = name.trim().toLowerCase();
            final known = globalItemDetails[key];
            if (known != null) {
              rateCtrl.text = known.rate > 0
                  ? known.rate.toStringAsFixed(known.rate.truncateToDouble() == known.rate ? 0 : 2)
                  : rateCtrl.text;
              unitCtrl.text = known.unit.isNotEmpty ? known.unit : unitCtrl.text;
              discCtrl.text = known.discount > 0 ? known.discount.toStringAsFixed(0) : discCtrl.text;
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  index == -1 ? 'Add Item to Sale' : 'Edit Item',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),

                // ── Autocomplete Item Name (Global — from all past invoices) ──
                RawAutocomplete<String>(
                  textEditingController: nameTextCtrl,
                  focusNode: nameFocusNode,
                  optionsBuilder: (TextEditingValue textValue) {
                    final q = textValue.text.trim().toLowerCase();
                    // Show ALL known names if empty, or filter by query
                    final matches = q.isEmpty
                        ? globalItemNames.map((k) => globalItemDetails[k]!.name).toList()
                        : globalItemNames
                            .where((k) => k.contains(q))
                            .map((k) => globalItemDetails[k]!.name)
                            .toList();
                    matches.sort();
                    return matches.take(8);
                  },
                  onSelected: (String selectedName) {
                    nameTextCtrl.text = selectedName;
                    applyKnownItem(selectedName);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: index == -1,
                      decoration: const InputDecoration(
                        labelText: 'Item Name *',
                        hintText: 'e.g. Fish, Crab, Service...',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                      ),
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: options.map((option) {
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 10),
                                      Text(
                                        option,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // ─────────────────────────────────────────────────────────────

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit (Kg/PCS)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Rate (₹)', hintText: '0.00', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Discount (%)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final name = nameTextCtrl.text.trim();
                      if (name.isEmpty) return;
                      final q = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                      final r = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
                      final d = double.tryParse(discCtrl.text.trim()) ?? 0.0;
                      final u = unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'Kg';

                      final newItem = _SaleItemDraft(
                        name: name,
                        quantity: q,
                        rate: r,
                        unit: u,
                        discount: d,
                        discountType: 'PERCENT',
                        gstRate: 0.0,
                      );

                      setState(() {
                        if (index == -1) {
                          _items.add(newItem);
                        } else {
                          _items[index] = newItem;
                        }
                        // Save to known items for future autocomplete in this session
                        _knownItemDetails[name.toLowerCase()] = newItem;
                        if (_isReceivedChecked) {
                          _receivedAmountController.text = _computeTotal().toStringAsFixed(2);
                        }
                      });

                      // Automatically store into Product & Service Catalog for later purpose & suggestions
                      try {
                        productProvider.addOrUpdateItem(
                          name: name,
                          price: r,
                          unit: u,
                        );
                      } catch (_) {}
                      Navigator.pop(ctx);
                    },
                    child: Text(index == -1 ? 'Add to Bill' : 'Update Item', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
