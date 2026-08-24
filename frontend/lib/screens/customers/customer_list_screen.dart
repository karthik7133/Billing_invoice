import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/customer_card.dart';
import '../../widgets/empty_state_widget.dart';
import 'add_edit_customer_screen.dart';
import '../invoices/create_invoice_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'ALL'; // 'ALL', 'B2B', 'B2C'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);

    var customers = customerProvider.customers;
    if (_selectedFilter == 'B2B') {
      customers = customers.where((c) => c.isRegistered).toList();
    } else if (_selectedFilter == 'B2C') {
      customers = customers.where((c) => !c.isRegistered).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
              );
            },
            tooltip: 'Add Customer',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                customerProvider.setSearchQuery(val);
              },
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or GSTIN...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          customerProvider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),

          // 2. Filter Chips — horizontally scrollable so they never overflow
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Customers'),
                const SizedBox(width: 8),
                _buildFilterChip('B2B', 'B2B (Registered)'),
                const SizedBox(width: 8),
                _buildFilterChip('B2C', 'B2C (Consumers)'),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Customer List
          Expanded(
            child: customers.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.people_outline,
                    title: 'No Customers Found',
                    description: _searchController.text.isNotEmpty
                        ? 'Try searching with a different name, phone, or GSTIN'
                        : 'Start adding customers to create GST invoices faster.',
                    buttonText: 'Add First Customer',
                    onButtonPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: customers.length,
                    itemBuilder: (ctx, i) {
                      final customer = customers[i];
                      return CustomerCard(
                        customer: customer,
                        onTap: () {
                          _showCustomerActionSheet(context, customer);
                        },
                        onEdit: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => AddEditCustomerScreen(customer: customer),
                            ),
                          );
                        },
                        onDelete: () {
                          _confirmDeleteCustomer(context, customer);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addCustomerFab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
          );
        },
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      onSelected: (val) {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
    );
  }

  void _showCustomerActionSheet(BuildContext context, CustomerModel customer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      customer.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Text(
                '${customer.state} • ${customer.customerType.replaceAll('_', ' ')}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.post_add_rounded, color: AppColors.primary),
                title: const Text('Create Invoice for this Customer'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (c) => CreateInvoiceScreen(preselectedCustomer: customer),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                title: const Text('Edit Customer Details'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (c) => AddEditCustomerScreen(customer: customer),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete Customer', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteCustomer(context, customer);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCustomer(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to delete ${customer.name}? This will not affect previously created invoices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Provider.of<CustomerProvider>(context, listen: false).deleteCustomer(customer.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Customer ${customer.name} deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
