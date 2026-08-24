import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/customer_card.dart';
import '../../widgets/empty_state_widget.dart';
import 'add_edit_customer_screen.dart';
import 'party_details_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'ALL'; // 'ALL', 'B2B', 'B2C'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

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
            onPressed: () async {
              final created = await Navigator.of(context).push<CustomerModel>(
                MaterialPageRoute(builder: (ctx) => const AddEditCustomerScreen()),
              );
              if (created != null) {
                customerProvider.fetchCustomers();
              }
            },
            tooltip: 'Add Customer',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => customerProvider.fetchCustomers(),
        child: Column(
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
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (c) => PartyDetailsScreen(customer: customer)),
                            );
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
