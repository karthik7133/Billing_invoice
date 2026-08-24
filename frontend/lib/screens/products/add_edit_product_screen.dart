import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/gst_rates.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';

class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _hsnController;
  late TextEditingController _priceController;

  String _itemType = 'PRODUCT';
  String _selectedUnit = 'PCS';
  double _selectedGstRate = 18.0;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _hsnController = TextEditingController(text: p?.hsnSac ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');

    if (p != null) {
      _itemType = p.itemType;
      _selectedUnit = p.unit.isNotEmpty ? p.unit : 'PCS';
      _selectedGstRate = p.gstRate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _hsnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;

    final model = ProductModel(
      id: widget.product?.id ?? '',
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      hsnSac: _hsnController.text.trim(),
      itemType: _itemType,
      unit: _selectedUnit,
      price: price,
      gstRate: _selectedGstRate,
    );

    if (widget.product != null) {
      await productProvider.updateProduct(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } else {
      final created = await productProvider.addProduct(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Item' : 'Add New Item / Service'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _saveProduct,
            tooltip: 'Save',
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
              // 1. Item Type Selector
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Item Classification',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Physical Product (Goods)')),
                            selected: _itemType == 'PRODUCT',
                            selectedColor: AppColors.primary.withValues(alpha: 0.12),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _itemType = 'PRODUCT';
                                  if (_selectedUnit == 'SERVICE') _selectedUnit = 'PCS';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Service')),
                            selected: _itemType == 'SERVICE',
                            selectedColor: AppColors.primary.withValues(alpha: 0.12),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _itemType = 'SERVICE';
                                  _selectedUnit = 'SERVICE';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Product Name & Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    CustomTextField(
                      label: _itemType == 'PRODUCT' ? 'Product Name' : 'Service Name',
                      controller: _nameController,
                      isRequired: true,
                      hintText: _itemType == 'PRODUCT' ? 'e.g. Samsung Charger 25W' : 'e.g. Software Development',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Description / Model Info (Optional)',
                      controller: _descController,
                      hintText: 'e.g. Color, specifications, model number',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: _itemType == 'PRODUCT' ? 'HSN Code' : 'SAC Code',
                            controller: _hsnController,
                            hintText: _itemType == 'PRODUCT' ? 'e.g. 8504' : 'e.g. 9983',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomDropdown<String>(
                            label: 'Measuring Unit',
                            value: _selectedUnit,
                            items: GstConstants.units.map((u) {
                              return DropdownMenuItem<String>(
                                value: u,
                                child: Text(u),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedUnit = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Pricing & GST Rate Slab
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      label: 'Base Rate / Selling Price (₹)',
                      controller: _priceController,
                      isRequired: true,
                      hintText: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: const Icon(Icons.currency_rupee, size: 18, color: AppColors.textPrimary),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Price is required';
                        if (double.tryParse(val.trim()) == null) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'GST Tax Rate Slab',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GstConstants.gstRates.map((rate) {
                        final isSelected = _selectedGstRate == rate;
                        return ChoiceChip(
                          label: Text(
                            rate == 0 ? '0% (Exempt)' : '${rate.toStringAsFixed(0)}% GST',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          backgroundColor: AppColors.surface,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedGstRate = rate;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveProduct,
                  icon: const Icon(Icons.check),
                  label: Text(isEditing ? 'UPDATE ITEM' : 'SAVE ITEM TO CATALOG'),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
