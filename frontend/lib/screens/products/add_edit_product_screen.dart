import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/custom_text_field.dart';

class AddEditProductScreen extends StatefulWidget {
  final ProductModel? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;

  final List<String> _quickUnits = ['Kg', 'PCS', 'BOX', 'LTR', 'NOS', 'BAG', 'PKT'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(
      text: p != null && p.price > 0
          ? (p.price == p.price.truncateToDouble() ? p.price.toInt().toString() : p.price.toStringAsFixed(2))
          : '',
    );
    _unitController = TextEditingController(text: p?.unit.isNotEmpty == true ? p!.unit : 'Kg');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final unit = _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : 'Kg';

    final model = ProductModel(
      id: widget.product?.id ?? '',
      name: _nameController.text.trim(),
      description: '',
      hsnSac: '',
      itemType: 'PRODUCT',
      unit: unit,
      price: price,
      gstRate: 0.0,
    );

    if (widget.product != null) {
      await productProvider.updateProduct(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } else {
      final created = await productProvider.addProduct(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added to catalog successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          isEditing ? 'Edit Item' : 'Add Item to Catalog',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF2563EB)),
            onPressed: _saveProduct,
            tooltip: 'Save',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card container with fields
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Item Name
                    CustomTextField(
                      label: 'Item / Product Name *',
                      controller: _nameController,
                      isRequired: true,
                      hintText: 'e.g. Pomfret, Fish, Crab, Rice...',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Item name is required' : null,
                    ),

                    const SizedBox(height: 18),

                    // 2. Rate / Price
                    CustomTextField(
                      label: 'Rate / Price (₹) *',
                      controller: _priceController,
                      isRequired: true,
                      hintText: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: const Icon(Icons.currency_rupee, size: 18, color: Color(0xFF0F172A)),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Rate is required';
                        if (double.tryParse(val.trim()) == null) return 'Enter a valid rate';
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // 3. Unit
                    const Text(
                      'Unit *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _unitController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Kg, PCS, BOX',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick unit selection chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickUnits.map((u) {
                        final isSelected = _unitController.text.trim().toLowerCase() == u.toLowerCase();
                        return ActionChip(
                          label: Text(
                            u,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                            ),
                          ),
                          backgroundColor: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          onPressed: () {
                            setState(() {
                              _unitController.text = u;
                            });
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
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveProduct,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    isEditing ? 'UPDATE ITEM' : 'SAVE ITEM TO CATALOG',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
