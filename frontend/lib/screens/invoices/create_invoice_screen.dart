import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/gst_rates.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import 'invoice_detail_screen.dart';

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

  // Invoice number prefix — 'NO' means no prefix
  String _invoicePrefix = 'NO';

  final List<_SaleItemDraft> _items = [];
  final List<XFile> _attachedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _invoiceDate = widget.existingInvoice?.invoiceDate ?? DateTime.now();
    _selectedOrigin = (widget.existingInvoice?.origin.isNotEmpty == true) ? widget.existingInvoice!.origin : 'AP';

    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final business = businessProvider.business;

    final defaultInvoiceNo = widget.existingInvoice != null
        ? widget.existingInvoice!.invoiceNumber
        : '${business.nextInvoiceNumber > 0 ? business.nextInvoiceNumber : 1}';

    _invoiceNoController = TextEditingController(text: defaultInvoiceNo);
    _descriptionController = TextEditingController(text: widget.existingInvoice?.description ?? '');
    _termsAndConditions = widget.existingInvoice?.termsAndConditions ?? business.termsAndConditions;

    if (widget.existingInvoice != null) {
      _selectedCustomer = widget.existingInvoice!.customerSnapshot;
      _customerNameController = TextEditingController(text: _selectedCustomer?.name ?? '');
      _billingNameController = TextEditingController(text: _selectedCustomer?.billingName ?? '');
      _phoneController = TextEditingController(text: _selectedCustomer?.phone ?? '');

      for (final it in widget.existingInvoice!.items) {
        _items.add(
          _SaleItemDraft(
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
          ),
        );
      }
      _receivedAmountController = TextEditingController(
        text: widget.existingInvoice!.amountPaid > 0 ? widget.existingInvoice!.amountPaid.toStringAsFixed(2) : '',
      );
      _isReceivedChecked = widget.existingInvoice!.amountPaid > 0;
      _paymentType = widget.existingInvoice!.paymentType.isNotEmpty ? widget.existingInvoice!.paymentType : 'Cash';
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        setState(() {
          _attachedImages.add(picked);
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Photo / Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
                ),
                title: const Text('Take Photo (Camera)'),
                subtitle: const Text('Capture invoice, bill or delivery receipt'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Upload an existing photo from device'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePreviewDialog(XFile file, int index) {
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
                  child: kIsWeb
                      ? Image.network(file.path, fit: BoxFit.contain, height: 320)
                      : Image.file(File(file.path), fit: BoxFit.contain, height: 320),
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

    final prefixOptions = ['NO', 'N', 'AP', 'ORS', 'ORS/LT', 'INV', 'BILL', 'GEN'];
    String tempPrefix = _invoicePrefix;
    final tempNumberCtrl = TextEditingController(text: _invoiceNoController.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Change Invoice No.',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Invoice Prefix label
                    const Text(
                      'Invoice Prefix',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    // Scrollable prefix chips row
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: prefixOptions.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final opt = prefixOptions[i];
                          final isSelected = tempPrefix == opt;
                          return GestureDetector(
                            onTap: () => setSheet(() => tempPrefix = opt),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                opt,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Invoice No. input
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: tempNumberCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Invoice No.',
                          labelStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // SAVE button
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'SAVE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
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

  void _saveSale() async {
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

    final custProvider = Provider.of<CustomerProvider>(context, listen: false);
    final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
    final busProvider = Provider.of<BusinessProvider>(context, listen: false);

    CustomerModel customer;
    if (_selectedCustomer != null && _selectedCustomer!.name.toLowerCase() == name.toLowerCase()) {
      customer = _selectedCustomer!;
    } else {
      // Find or create customer dynamically
      final existing = custProvider.findByName(name);
      if (existing != null) {
        customer = existing;
      } else {
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

    final rawItems = _items.map((it) => it.toMap()).toList();
    final receivedInput = double.tryParse(_receivedAmountController.text.trim()) ?? 0.0;
    final amountPaid = _isReceivedChecked ? receivedInput : 0.0;

    // Upload attached images to Cloudinary
    final uploadedUrls = <String>[];
    if (_attachedImages.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Uploading attached photos to Cloudinary...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      for (final img in _attachedImages) {
        final url = await invProvider.uploadAttachment(img);
        if (url != null && url.isNotEmpty) {
          uploadedUrls.add(url);
        }
      }
    }

    final invoice = await invProvider.createInvoice(
      customer: customer,
      business: busProvider.business,
      rawItems: rawItems,
      invoiceNumber: _buildFinalInvoiceNo(),
      invoiceDate: _invoiceDate,
      origin: _selectedOrigin,
      attachments: uploadedUrls,
      amountPaid: amountPaid,
      paymentType: _paymentType,
      description: _descriptionController.text.trim(),
      termsAndConditions: _termsAndConditions,
    );

    // Refresh customers so balance is updated dynamically
    await custProvider.fetchCustomers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sale #${invoice.invoiceNumber} saved successfully'),
          backgroundColor: AppColors.receivableGreen,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (ctx) => InvoiceDetailScreen(invoice: invoice)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _computeTotal();
    final totalDiscount = _computeTotalDiscount();
    final totalTax = _computeTotalTax();
    final receivedInput = double.tryParse(_receivedAmountController.text.trim()) ?? 0.0;
    final amountPaid = _isReceivedChecked ? receivedInput : 0.0;
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
        title: const Text(
          'Sale',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
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
      body: SingleChildScrollView(
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
                        const Text('Origin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedOrigin,
                            isDense: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB), size: 18),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            items: const [
                              DropdownMenuItem(value: 'AP', child: Text('AP (Andhra)')),
                              DropdownMenuItem(value: 'ORRISA', child: Text('ORRISA')),
                              DropdownMenuItem(value: 'GUJARAT', child: Text('GUJARAT')),
                              DropdownMenuItem(value: 'KARNATAKA', child: Text('KARNATAKA')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedOrigin = val);
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

                  const SizedBox(height: 12),

                  // Received Checkbox & Amount
                  Row(
                    children: [
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
                      const Spacer(),
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

                  // Extra Over Money Banner
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
                                'Over Due (Extra / Advance Paid):',
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

                  // Payment Type Selector
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
                            value: _paymentType,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'Cash', child: Text('💵 Cash')),
                              DropdownMenuItem(value: 'Bank Transfer', child: Text('🏦 Bank Transfer')),
                              DropdownMenuItem(value: 'UPI', child: Text('📱 UPI / GPay')),
                              DropdownMenuItem(value: 'Cheque', child: Text('📝 Cheque')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _paymentType = val);
                            },
                          ),
                        ),
                      ),
                    ],
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
                                    child: kIsWeb
                                        ? Image.network(img.path, fit: BoxFit.cover)
                                        : Image.file(File(img.path), fit: BoxFit.cover),
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

      // 8. Bottom Bar: Delete | Save (Blue button)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5), // Vibrant blue Save button
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Save Sale',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
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
    final nameCtrl = TextEditingController(text: draft.name);
    final qtyCtrl = TextEditingController(
      text: draft.quantity > 0 ? draft.quantity.toStringAsFixed(draft.quantity.truncateToDouble() == draft.quantity ? 0 : 2) : '1',
    );
    final rateCtrl = TextEditingController(
      text: draft.rate > 0 ? draft.rate.toStringAsFixed(draft.rate.truncateToDouble() == draft.rate ? 0 : 2) : '',
    );
    final unitCtrl = TextEditingController(text: draft.unit);
    final discCtrl = TextEditingController(text: draft.discount > 0 ? draft.discount.toStringAsFixed(0) : '0');
    double selectedGst = draft.gstRate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
              TextField(
                controller: nameCtrl,
                autofocus: index == -1,
                decoration: const InputDecoration(labelText: 'Item Name *', hintText: 'e.g. Fish, Crab, Service...', border: OutlineInputBorder()),
              ),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: discCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Discount (%)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: selectedGst,
                      decoration: const InputDecoration(labelText: 'GST Rate', border: OutlineInputBorder()),
                      items: GstRates.standardRates.map((r) {
                        return DropdownMenuItem(value: r, child: Text('${r.toInt()}%'));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => selectedGst = v);
                      },
                    ),
                  ),
                ],
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
                    final name = nameCtrl.text.trim();
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
                      gstRate: selectedGst,
                    );

                    setState(() {
                      if (index == -1) {
                        _items.add(newItem);
                      } else {
                        _items[index] = newItem;
                      }
                      if (_isReceivedChecked) {
                        _receivedAmountController.text = _computeTotal().toStringAsFixed(2);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(index == -1 ? 'Add to Bill' : 'Update Item', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
