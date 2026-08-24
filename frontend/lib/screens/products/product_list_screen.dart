import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/empty_state_widget.dart';
import 'add_edit_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'ALL'; // 'ALL', 'PRODUCT', 'SERVICE'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    var products = productProvider.products;
    if (_selectedFilter != 'ALL') {
      products = products.where((p) => p.itemType == _selectedFilter).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product & Service Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AddEditProductScreen()),
              );
            },
            tooltip: 'Add Item',
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
                productProvider.setSearchQuery(val);
              },
              decoration: InputDecoration(
                hintText: 'Search products by name, HSN/SAC...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          productProvider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),

          // 2. Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Items'),
                const SizedBox(width: 8),
                _buildFilterChip('PRODUCT', 'Products (Goods)'),
                const SizedBox(width: 8),
                _buildFilterChip('SERVICE', 'Services'),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 3. Products List
          Expanded(
            child: products.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No Catalog Items',
                    description: _searchController.text.isNotEmpty
                        ? 'Try searching with a different product or HSN code'
                        : 'Add products or services with HSN/SAC and GST rates for 1-click billing.',
                    buttonText: 'Add Product / Service',
                    onButtonPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => const AddEditProductScreen()),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: products.length,
                    itemBuilder: (ctx, i) {
                      final product = products[i];
                      return ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => AddEditProductScreen(product: product),
                            ),
                          );
                        },
                        onEdit: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => AddEditProductScreen(product: product),
                            ),
                          );
                        },
                        onDelete: () {
                          _confirmDeleteProduct(context, product);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addProductFab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddEditProductScreen()),
          );
        },
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_shopping_cart_rounded),
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

  void _confirmDeleteProduct(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Product ${product.name} deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
