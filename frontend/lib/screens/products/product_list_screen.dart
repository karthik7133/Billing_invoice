import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/cloud_server_status_pill.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Product & Service Catalog',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
        ),
        actions: [
          const CloudServerStatusPill(compact: true),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Color(0xFF2563EB)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const AddEditProductScreen()),
              );
            },
            tooltip: 'Add Item',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => productProvider.fetchProducts(),
        child: Column(
          children: [
            // 1. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 19),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          productProvider.setSearchQuery(val);
                        },
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Search products by name, HSN/SAC...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        splashRadius: 18,
                        icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          productProvider.setSearchQuery('');
                        },
                      ),
                  ],
                ),
              ),
            ),

            // 2. Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addProductFab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddEditProductScreen()),
          );
        },
        backgroundColor: AppColors.vyaparPink,
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
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        width: 1,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.payableRed),
            onPressed: () {
              Provider.of<ProductProvider>(context, listen: false).deleteProduct(product.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Product "${product.name}" deleted'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
