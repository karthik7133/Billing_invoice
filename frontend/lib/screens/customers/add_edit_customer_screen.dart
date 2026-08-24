import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/indian_states.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final CustomerModel? customer;

  const AddEditCustomerScreen({super.key, this.customer});

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _gstinController;
  late TextEditingController _panController;
  late TextEditingController _billingAddressController;
  late TextEditingController _shippingAddressController;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;

  String _customerType = 'UNREGISTERED_B2C';
  String _selectedState = 'Andhra Pradesh';
  String _selectedStateCode = '37';
  bool _sameShipping = true;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;

    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _gstinController = TextEditingController(text: c?.gstin ?? '');
    _panController = TextEditingController(text: c?.pan ?? '');
    _billingAddressController = TextEditingController(text: c?.billingAddress ?? '');
    _shippingAddressController = TextEditingController(text: c?.shippingAddress ?? '');
    _cityController = TextEditingController(text: c?.city ?? '');
    _pincodeController = TextEditingController(text: c?.pincode ?? '');

    if (c != null) {
      _customerType = c.customerType;
      _selectedState = c.state.isNotEmpty ? c.state : 'Andhra Pradesh';
      _selectedStateCode = c.stateCode.isNotEmpty ? c.stateCode : IndianStates.getCodeByName(_selectedState);
      _sameShipping = c.shippingAddress.isEmpty || c.shippingAddress == c.billingAddress;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    final billing = _billingAddressController.text.trim();
    final shipping = _sameShipping ? billing : _shippingAddressController.text.trim();

    final model = CustomerModel(
      id: widget.customer?.id ?? '',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      billingAddress: billing,
      shippingAddress: shipping,
      city: _cityController.text.trim(),
      state: _selectedState,
      stateCode: _selectedStateCode,
      pincode: _pincodeController.text.trim(),
      gstin: _gstinController.text.trim().toUpperCase(),
      pan: _panController.text.trim().toUpperCase(),
      customerType: _customerType,
    );

    if (widget.customer != null) {
      await customerProvider.updateCustomer(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer updated successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } else {
      final created = await customerProvider.addCustomer(model);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer added successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, created);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.customer != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'Add New Customer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _saveCustomer,
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
              // 1. Customer Type Selector (B2B vs B2C)
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
                      'Customer Category',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Registered B2B (GST)')),
                            selected: _customerType == 'REGISTERED_B2B',
                            selectedColor: AppColors.primary.withValues(alpha: 0.12),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _customerType = 'REGISTERED_B2B';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Consumer B2C')),
                            selected: _customerType == 'UNREGISTERED_B2C',
                            selectedColor: AppColors.primary.withValues(alpha: 0.12),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _customerType = 'UNREGISTERED_B2C';
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

              // 2. Basic Contact Details
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
                      label: 'Customer / Business Name',
                      controller: _nameController,
                      isRequired: true,
                      hintText: 'e.g. Ravi Electronics or John Doe',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Customer name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            hintText: '10 digit mobile',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            label: 'Email',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            hintText: 'name@domain.com',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. GST & State Details
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
                    CustomDropdown<String>(
                      label: 'Customer State (Place of Supply)',
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
                            label: _customerType == 'REGISTERED_B2B' ? 'GSTIN (15 Digits)' : 'GSTIN (Optional)',
                            controller: _gstinController,
                            hintText: '37XXXXXXXXXX1Z5',
                            isRequired: _customerType == 'REGISTERED_B2B',
                            onChanged: (val) {
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
                            label: 'PAN (Optional)',
                            controller: _panController,
                            hintText: 'ABCDE1234F',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Address Details
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
                      label: 'Billing Address',
                      controller: _billingAddressController,
                      hintText: 'Shop / House No, Street, Landmark',
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
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: _sameShipping,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _sameShipping = val ?? true;
                            });
                          },
                        ),
                        const Text(
                          'Shipping address is same as billing address',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (!_sameShipping) ...[
                      const SizedBox(height: 10),
                      CustomTextField(
                        label: 'Shipping Address',
                        controller: _shippingAddressController,
                        hintText: 'Delivery address if different from billing',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveCustomer,
                  icon: const Icon(Icons.check),
                  label: Text(isEditing ? 'UPDATE CUSTOMER' : 'SAVE CUSTOMER'),
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
