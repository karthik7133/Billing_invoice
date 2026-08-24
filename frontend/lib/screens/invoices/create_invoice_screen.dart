import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/gst_rates.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/customer_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../services/share_service.dart';
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
  String _paymentType = 'Cash';
  bool _isReceivedChecked = true;
  bool _termsExpanded = false;
  String _termsAndConditions = '';

  final List<_SaleItemDraft> _items = [];

  @override
  void initState() {
    super.initState();
    _invoiceDate = widget.existingInvoice?.invoiceDate ?? DateTime.now();

    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final business = businessProvider.business;

    final defaultInvoiceNo = widget.existingInvoice != null
        ? widget.existingInvoice!.invoiceNumber
        : '${business.nextInvoiceNumber > 0 ? business.nextInvoiceNumber : 31}';

    _invoiceNoController = TextEditingController(text: defaultInvoiceNo);
    _descriptionController = TextEditingController(text: widget.existingInvoice?.description ?? 'PARTY EXPENSES NILL\nRAILWAY EXPENSES');
    _termsAndConditions = widget.existingInvoice?.termsAndConditions ?? business.termsAndConditions;

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    if (widget.preselectedCustomer != null) {
      _selectedCustomer = widget.preselectedCustomer;
    } else if (widget.existingInvoice != null) {
      _selectedCustomer = widget.existingInvoice!.customerSnapshot;
    } else if (customerProvider.customers.isNotEmpty) {
      _selectedCustomer = customerProvider.customers.first;
    }

    _customerNameController = TextEditingController(text: _selectedCustomer?.name ?? 'SVSF/TN');
    _billingNameController = TextEditingController(text: _selectedCustomer?.billingName.isNotEmpty == true ? _selectedCustomer!.billingName : (_selectedCustomer?.name ?? 'SVSF/TN'));
    _phoneController = TextEditingController(text: _selectedCustomer?.phone ?? '');

    // Pre-populate items
    if (widget.existingInvoice != null) {
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
      _receivedAmountController = TextEditingController(text: widget.existingInvoice!.amountPaid.toStringAsFixed(2));
      _isReceivedChecked = widget.existingInvoice!.amountPaid > 0;
      _paymentType = widget.existingInvoice!.paymentType.isNotEmpty ? widget.existingInvoice!.paymentType : 'Cash';
    } else {
      // Default initial sample item matching user's photo
      _items.add(
        _SaleItemDraft(
          name: 'BLUE COOKED CRAB',
          unit: 'Kg',
          quantity: 3,
          rate: 650,
          discount: 0,
          gstRate: 0,
        ),
      );
      _items.add(
        _SaleItemDraft(
          name: '3SPT COOKED RAW WT',
          unit: 'Kg',
          quantity: 987,
          rate: 340,
          discount: 0,
          gstRate: 0,
        ),
      );
      final total = _computeTotal();
      _receivedAmountController = TextEditingController(text: total.toStringAsFixed(2));
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
      // Find or create customer
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

    final invoice = await invProvider.createInvoice(
      customer: customer,
      business: busProvider.business,
      rawItems: rawItems,
      invoiceNumber: _invoiceNoController.text.trim(),
      invoiceDate: _invoiceDate,
      amountPaid: amountPaid,
      paymentType: _paymentType,
      description: _descriptionController.text.trim(),
      termsAndConditions: _termsAndConditions,
    );

    // Refresh customers so balance is updated in Party Details
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
    final partyBalance = _selectedCustomer?.balance ?? 1248732.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Sale',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black87),
            onPressed: () async {
              // Share draft text
              ShareService.shareText(
                text: 'Sale Draft for ${_customerNameController.text}: Total ${CurrencyFormatter.format(grandTotal)}',
                subject: 'Sale Estimate',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Invoice No & Date Row (Image 4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Invoice No
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'Invoice No.\nNo ',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.2),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _invoiceNoController,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: const Color(0xFFCBD5E1)),
                  const SizedBox(width: 12),
                  // Date
                  Expanded(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_invoiceDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Customer Section (Customer Name *, Billing Name, Phone) (Image 4)
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
                  // Customer Name with floating party balance & dropdown picker
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
                                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                ),
                                onChanged: (val) {
                                  final match = customerProvider.findByName(val);
                                  if (match != null) {
                                    _onCustomerSelected(match);
                                  }
                                },
                              ),
                            ),
                            if (customerProvider.customers.isNotEmpty)
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
                        ),
                      ),
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
                      labelText: 'Billing Name(Optional)',
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

            // 3. Billed Items Header Banner (Image 4)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFBFDBFE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Color(0xFF1E88E5)),
                  SizedBox(width: 6),
                  Text(
                    'Billed Items',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 4. Item Cards List (Image 4)
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
                    'Total Disc: ${totalDiscount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Total Tax Amt: ${totalTax.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

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

            // 5. Totals & Payment Section (Image 5)
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
                        '₹ ${grandTotal.toStringAsFixed(2)}',
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
                            _isReceivedChecked = val ?? true;
                            if (_isReceivedChecked && _receivedAmountController.text.isEmpty) {
                              _receivedAmountController.text = grandTotal.toStringAsFixed(2);
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
                        '₹ ${balanceDue.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.receivableGreen),
                      ),
                    ],
                  ),

                  // ── Extra Over Money Banner ──
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
                                'Extra / Over Money (Advance):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                          Text(
                            '₹ ${overMoney.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Payment Type Selector (Image 5)
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

            // 6. Description & Attachment (Image 5)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
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
                            labelText: 'Description',
                            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2563EB), size: 24),
                            SizedBox(height: 2),
                            Text('Image', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF64748B)),
                    label: const Text('Add Document', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 38),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 7. Terms & Conditions Accordion (Image 5)
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

      // 8. Bottom Bar: Delete | Save | 3 dots (Image 5)
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
                  'Delete',
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
                    'Save',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                onSelected: (val) {},
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'preview', child: Text('Preview PDF')),
                ],
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
                '₹ ${item.total.toStringAsFixed(0)}',
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
                '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.unit} x ${item.rate.toStringAsFixed(0)} = ₹ ${item.subtotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Discount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discount (${item.discountType == "PERCENT" ? "%" : "₹"}): ${item.discount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFE59819)),
              ),
              Text(
                '₹ ${item.discountAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFE59819)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tax
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax : ${item.gstRate.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Text(
                '₹ ${item.taxAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
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
    final qtyCtrl = TextEditingController(text: draft.quantity.toStringAsFixed(draft.quantity.truncateToDouble() == draft.quantity ? 0 : 2));
    final rateCtrl = TextEditingController(text: draft.rate.toStringAsFixed(draft.rate.truncateToDouble() == draft.rate ? 0 : 2));
    final unitCtrl = TextEditingController(text: draft.unit);
    final discCtrl = TextEditingController(text: draft.discount.toStringAsFixed(0));
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
                decoration: const InputDecoration(labelText: 'Item Name *', border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder()),
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
