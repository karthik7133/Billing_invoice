import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import 'dashboard_screen.dart';
import '../invoices/invoice_history_screen.dart';
import '../invoices/create_invoice_screen.dart';
import '../customers/customer_list_screen.dart';
import '../products/product_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // 4 real tabs: Home, Invoices, Customers, Products
  final List<Widget> _screens = const [
    DashboardScreen(),
    InvoiceHistoryScreen(),
    CustomerListScreen(),
    ProductListScreen(),
  ];

  void _onNavItemTapped(int index) {
    if (index == 2) {
      // Centre "+" — push create invoice
      HapticFeedback.mediumImpact();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
      );
      return;
    }
    // Remap: 0→0, 1→1, skip 2 (center), 3→2, 4→3
    final screenIndex = index > 2 ? index - 1 : index;
    setState(() => _currentIndex = screenIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }
}

// ─── Custom Bottom Navigation Bar ───────────────────────────────────────────

class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              _NavItem(
                navIndex: 0,
                screenIndex: 0,
                currentIndex: currentIndex,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Home',
                onTap: onTap,
              ),
              _NavItem(
                navIndex: 1,
                screenIndex: 1,
                currentIndex: currentIndex,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Invoices',
                onTap: onTap,
              ),
              // Centre "Create Invoice" button
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryGradientStart,
                              AppColors.primaryGradientEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'New',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(
                navIndex: 3,
                screenIndex: 2,
                currentIndex: currentIndex,
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'Customers',
                onTap: onTap,
              ),
              _NavItem(
                navIndex: 4,
                screenIndex: 3,
                currentIndex: currentIndex,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: 'Products',
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int navIndex;
  final int screenIndex;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.navIndex,
    required this.screenIndex,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = screenIndex == currentIndex;
    final color = isSelected ? AppColors.primary : const Color(0xFFABB5C5);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(navIndex);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
