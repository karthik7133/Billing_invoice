import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/gst_rates.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/gst_calculator.dart';
import '../../core/utils/number_to_words.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/invoice_provider.dart';
import '../customers/add_edit_customer_screen.dart';
import 'invoice_detail_screen.dart';
import 'invoice_pdf_preview_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final CustomerModel? preselectedCustomer;

  const CreateInvoiceScreen({super.key, this.preselectedCustomer});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _InvoiceItemDraft {
  String? productId;
  String name;
  String description;
  String hsnSac;
  String unit;
  double quantity;
  double rate;
  double discount;
  String discountType;
  double gstRate;

  _InvoiceItemDraft({
    this.productId,
    this.name = '',
    this.description = '',
    this.hsnSac = '',
    this.unit = 'PCS',
    this.quantity = 1.0,
    this.rate = 0.0,
    this.discount = 0.0,
    this.discountType = 'FIXED',
    this.gstRate = 18.0,
  });

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
  late DateTime _invoiceDate;
  late DateTime _dueDate;
  late String _invoiceNumber;

  final List<_InvoiceItemDraft> _items = [];

  final double _invoiceDiscount = 0.0;
  final String _invoiceDiscountType = 'FIXED';
  double _otherCharges = 0.0;
  double _amountPaid = 0.0;
  String _notes = 'Thank you for your business!';

  @override
  void initState() {
    super.initState();
    _invoiceDate = DateTime.now();
    _dueDate = DateTime.now().add(const Duration(days: 15));

    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final business = businessProvider.business;
    _invoiceNumber = '${business.invoicePrefix}-${business.nextInvoiceNumber.toString().padLeft(4, '0')}';

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    if (widget.preselectedCustomer != null) {
      _selectedCustomer = widget.preselectedCustomer;
    } else if (customerProvider.customers.isNotEmpty) {
      _selectedCustomer = customerProvider.customers.first;
    }

    // Pre-populate with one default item row
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    if (productProvider.products.isNotEmpty) {
      final p = productProvider.products.first;
      _items.add(
        _InvoiceItemDraft(
          productId: p.id,
          name: p.name,
          description: p.description,
          hsnSac: p.hsnSac,
          unit: p.unit,
          quantity: 1,
          rate: p.price,
          discount: 0.0,
          discountType: 'FIXED',
          gstRate: p.gstRate,
        ),
      );
    } else {
      _items.add(_InvoiceItemDraft(name: '', quantity: 1, rate: 0, discount: 0.0, discountType: 'FIXED', gstRate: 18.0));
    }
  }

  void _addItemFromCatalog(ProductModel product) {
    setState(() {
      _items.add(
        _InvoiceItemDraft(
          productId: product.id,
          name: product.name,
          description: product.description,
          hsnSac: product.hsnSac,
          unit: product.unit,
          quantity: 1,
          rate: product.price,
          discount: 0.0,
          discountType: 'FIXED',
          gstRate: product.gstRate,
        ),
      );
    });
  }

  void _addNewBlankItem() {
    setState(() {
      _items.add(_InvoiceItemDraft(name: '', quantity: 1, rate: 0, discount: 0.0, discountType: 'FIXED', gstRate: 18.0));
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item is required in the invoice.')),
      );
      return;
    }
    setState(() {
      _items.removeAt(index);
    });
  }

  InvoiceTotalsResult _calculateTotals() {
    final business = Provider.of<BusinessProvider>(context, listen: false).business;
    final sellerState = business.state;
    final buyerState = _selectedCustomer?.state ?? sellerState;

    final rawList = _items.map((i) => i.toMap()).toList();

    return GstCalculator.calculateInvoiceTotals(
      items: rawList,
      sellerState: sellerState,
      buyerState: buyerState,
      invoiceDiscount: _invoiceDiscount,
      invoiceDiscountType: _invoiceDiscountType,
      otherCharges: _otherCharges,
    );
  }

  Future<InvoiceModel?> _saveInvoice({bool openPdf = false}) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer for this invoice.'), backgroundColor: AppColors.error),
      );
      return null;
    }

    for (int i = 0; i < _items.length; i++) {
      if (_items[i].name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item #${i + 1} requires a name.'), backgroundColor: AppColors.error),
        );
        return null;
      }
    }

    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);

    final rawList = _items.map((i) => i.toMap()).toList();

    final createdInvoice = await invoiceProvider.createInvoice(
      customer: _selectedCustomer!,
      business: businessProvider.business,
      rawItems: rawList,
      invoiceNumber: _invoiceNumber,
      invoiceDate: _invoiceDate,
      dueDate: _dueDate,
      invoiceDiscount: _invoiceDiscount,
      invoiceDiscountType: _invoiceDiscountType,
      otherCharges: _otherCharges,
      status: _amountPaid >= _calculateTotals().grandTotal ? 'PAID' : (_amountPaid > 0 ? 'PARTIALLY_PAID' : 'ISSUED'),
      amountPaid: _amountPaid,
      notes: _notes,
    );

    businessProvider.incrementNextInvoiceNumber();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice ${createdInvoice.invoiceNumber} saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      if (openPdf) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => InvoicePdfPreviewScreen(invoice: createdInvoice),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => InvoiceDetailScreen(invoice: createdInvoice),
          ),
        );
      }
    }
    return createdInvoice;
  }

  @override
  Widget build(BuildContext context) {
    final business = Provider.of<BusinessProvider>(context).business;
    final customerProvider = Provider.of<CustomerProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    final totals = _calculateTotals();
    final isInterState = totals.isInterState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create GST Invoice'),
        actions: [
          TextButton.icon(
            onPressed: () => _saveInvoice(openPdf: true),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.primary),
            label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Invoice Header Card (Number, Dates)
            _buildInvoiceMetaCard(),

            const SizedBox(height: 16),

            // 2. Customer Selector & Place of Supply indicator
            _buildCustomerSelectionCard(customerProvider, business),

            const SizedBox(height: 16),

            // 3. Line Items Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Invoice Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                // Buttons row — compact labels to avoid overflow
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showCatalogPicker(productProvider),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('Catalog'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _addNewBlankItem,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Row'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Items List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _buildItemEditorCard(i, isInterState),
            ),

            const SizedBox(height: 20),

            // 4. Invoice Level Charges & Payment
            _buildAdditionalChargesCard(),

            const SizedBox(height: 20),

            // 5. Live GST & Financial Breakdown Summary
            _buildTotalsSummaryCard(totals),

            const SizedBox(height: 24),

            // 6. Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _saveInvoice(openPdf: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('SAVE INVOICE'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveInvoice(openPdf: true),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    label: const Text('SAVE & PREVIEW PDF'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Header Card
  Widget _buildInvoiceMetaCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Number — full width
          const Text('Invoice Number', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: _invoiceNumber,
            onChanged: (val) => _invoiceNumber = val.trim(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 12),
          // Invoice Date + Due Date side by side — each gets half width
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invoice Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _invoiceDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _invoiceDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                CurrencyFormatter.formatDateShort(_invoiceDate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Due Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: _invoiceDate,
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                CurrencyFormatter.formatDateShort(_dueDate),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  // Customer Selection Card with State Determination
  Widget _buildCustomerSelectionCard(CustomerProvider customerProvider, dynamic business) {
    final sellerState = business.state.toString();
    final buyerState = _selectedCustomer?.state ?? sellerState;
    final isInterState = sellerState.toLowerCase().trim() != buyerState.toLowerCase().trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer / Bill To',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              InkWell(
                onTap: () async {
                  final added = await Navigator.of(context).push<CustomerModel>(
                    MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
                  );
                  if (added != null) {
                    setState(() {
                      _selectedCustomer = added;
                    });
                  }
                },
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 16, color: AppColors.primary),
                    SizedBox(width: 2),
                    Text('Add Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dropdown
          DropdownButtonFormField<CustomerModel>(
            initialValue: _selectedCustomer,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: customerProvider.customers.map((c) {
              return DropdownMenuItem<CustomerModel>(
                value: c,
                child: Text('${c.name} (${c.state})'),
              );
            }).toList(),
            onChanged: (c) {
              setState(() {
                _selectedCustomer = c;
              });
            },
          ),

          if (_selectedCustomer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedCustomer!.gstin.isNotEmpty)
                          Text('GSTIN: ${_selectedCustomer!.gstin}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(
                          'Place of Supply: ${_selectedCustomer!.state}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Live GST Determination Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInterState ? Colors.purple.withValues(alpha: 0.12) : AppColors.infoBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isInterState ? Colors.purple.withValues(alpha: 0.4) : AppColors.info.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isInterState ? 'Inter-State (IGST)' : 'Intra-State (CGST+SGST)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isInterState ? Colors.purple : AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Item Editor Card
  Widget _buildItemEditorCard(int index, bool isInterState) {
    final item = _items[index];

    final qty = item.quantity;
    final rate = item.rate;
    final gross = qty * rate;
    final discount = item.discount;
    final taxable = (gross - discount).clamp(0.0, gross);

    final itemTax = (taxable * item.gstRate) / 100;
    final itemTotal = taxable + itemTax;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Item Name & Delete Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.name,
                  onChanged: (val) => setState(() => item.name = val),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Item / Product Name',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2a: HSN/SAC code — full width
          TextFormField(
            initialValue: item.hsnSac,
            onChanged: (val) => item.hsnSac = val,
            decoration: const InputDecoration(
              labelText: 'HSN/SAC Code',
              hintText: '8504',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),

          const SizedBox(height: 8),

          // Row 2b: Unit + GST Rate — each 50% width, enough space for dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: item.unit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: GstConstants.units.map((u) {
                    return DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (u) => setState(() => item.unit = u ?? 'PCS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<double>(
                  initialValue: item.gstRate,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'GST Rate',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: GstConstants.gstRates.map((r) {
                    return DropdownMenuItem(value: r, child: Text('${r.toStringAsFixed(0)}%'));
                  }).toList(),
                  onChanged: (r) => setState(() => item.gstRate = r ?? 18.0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 3: Qty, Rate, Discount
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 1.0),
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.rate > 0 ? item.rate.toStringAsFixed(2) : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() => item.rate = double.tryParse(val) ?? 0.0),
                  decoration: const InputDecoration(
                    labelText: 'Rate (₹)',
                    hintText: '0.00',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.discount > 0 ? item.discount.toString() : '',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() => item.discount = double.tryParse(val) ?? 0.0),
                  decoration: const InputDecoration(
                    labelText: 'Discount (₹)',
                    hintText: '0',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 4: Calculated Item Row Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Taxable: ₹${taxable.toStringAsFixed(2)}  •  Tax: ₹${itemTax.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Total: ₹${itemTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Catalog Item Picker Bottom Sheet
  void _showCatalogPicker(ProductProvider productProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Item from Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(
                child: productProvider.products.isEmpty
                    ? const Center(child: Text('No products in catalog. Add rows manually.'))
                    : ListView.builder(
                        itemCount: productProvider.products.length,
                        itemBuilder: (c, idx) {
                          final prod = productProvider.products[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 18),
                            ),
                            title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('HSN: ${prod.hsnSac} • GST ${prod.gstRate.toStringAsFixed(0)}%'),
                            trailing: Text(CurrencyFormatter.format(prod.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _addItemFromCatalog(prod);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Additional Charges Card
  Widget _buildAdditionalChargesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Additional Charges & Payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() => _otherCharges = double.tryParse(val) ?? 0.0),
                  decoration: const InputDecoration(
                    labelText: 'Other Charges / Freight (₹)',
                    hintText: '0.00',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() => _amountPaid = double.tryParse(val) ?? 0.0),
                  decoration: const InputDecoration(
                    labelText: 'Amount Received (₹)',
                    hintText: '0.00',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _notes,
            onChanged: (val) => _notes = val,
            decoration: const InputDecoration(
              labelText: 'Notes / Remarks',
              hintText: 'Thank you for your business!',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // Live GST Breakdown Summary Box
  Widget _buildTotalsSummaryCard(InvoiceTotalsResult totals) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tax & Grand Total Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow('Subtotal (Gross):', CurrencyFormatter.format(totals.subtotal)),
          if (totals.totalDiscount > 0)
            _buildSummaryRow('Total Discount:', '- ${CurrencyFormatter.format(totals.totalDiscount)}', isRed: true),
          _buildSummaryRow('Taxable Amount:', CurrencyFormatter.format(totals.taxableAmount)),
          const Divider(height: 12),

          // GST breakdown
          if (!totals.isInterState) ...[
            _buildSummaryRow('CGST (Central Tax):', CurrencyFormatter.format(totals.cgst)),
            _buildSummaryRow('SGST (State Tax):', CurrencyFormatter.format(totals.sgst)),
          ] else ...[
            _buildSummaryRow('IGST (Integrated Inter-state Tax):', CurrencyFormatter.format(totals.igst), isPurple: true),
          ],
          _buildSummaryRow('Total Tax (GST):', CurrencyFormatter.format(totals.totalTax)),

          if (totals.otherCharges > 0)
            _buildSummaryRow('Other Charges:', CurrencyFormatter.format(totals.otherCharges)),
          if (totals.roundOff != 0)
            _buildSummaryRow('Round Off:', CurrencyFormatter.format(totals.roundOff)),

          const Divider(height: 16, thickness: 1.2),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total:',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                CurrencyFormatter.format(totals.grandTotal),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            NumberToWords.convertToIndianWords(totals.grandTotal),
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (_amountPaid > 0) ...[
            const SizedBox(height: 8),
            const Divider(height: 10),
            _buildSummaryRow('Amount Received:', CurrencyFormatter.format(_amountPaid), isGreen: true),
            _buildSummaryRow(
              'Balance Due:',
              CurrencyFormatter.format((totals.grandTotal - _amountPaid).clamp(0.0, totals.grandTotal)),
              isRed: true,
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isRed = false, bool isGreen = false, bool isPurple = false, bool isBold = false}) {
    Color color = AppColors.textPrimary;
    if (isRed) color = AppColors.error;
    if (isGreen) color = AppColors.success;
    if (isPurple) color = Colors.purple;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
