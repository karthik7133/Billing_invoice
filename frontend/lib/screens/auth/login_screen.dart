import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/indian_states.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;

  final TextEditingController _nameController = TextEditingController(text: 'Ravi Kumar');
  final TextEditingController _businessNameController = TextEditingController(text: 'ABC Electronics & Retail');
  final TextEditingController _emailController = TextEditingController(text: 'ravi@abcelectronics.in');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');
  final TextEditingController _phoneController = TextEditingController(text: '9876543210');
  final TextEditingController _gstinController = TextEditingController(text: '37AAAAA0000A1Z5');

  String _selectedState = 'Andhra Pradesh';

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success;
    if (_isLogin) {
      success = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } else {
      success = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        businessName: _businessNameController.text.trim(),
        state: _selectedState,
        gstin: _gstinController.text.trim().toUpperCase(),
      );
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Something went wrong. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    // On success, _AppRouter in main.dart watches isAuthenticated and auto-navigates
  }

  void _demoLogin() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.loginAsDemo();
    // Auth router watches isAuthenticated and auto-navigates
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Gradient Header with App Branding
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 65, bottom: 35, left: 24, right: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'GST Billing App',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Professional GST Invoicing & Accounting Engine',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Auth Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Toggle Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isLogin = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isLogin ? AppColors.surface : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _isLogin
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: _isLogin ? FontWeight.w700 : FontWeight.w500,
                                      color: _isLogin ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isLogin = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isLogin ? AppColors.surface : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !_isLogin
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    'Register Business',
                                    style: TextStyle(
                                      fontWeight: !_isLogin ? FontWeight.w700 : FontWeight.w500,
                                      color: !_isLogin ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (!_isLogin) ...[
                      CustomTextField(
                        label: 'Your Name',
                        controller: _nameController,
                        isRequired: true,
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Business Name',
                        controller: _businessNameController,
                        isRequired: true,
                        prefixIcon: const Icon(Icons.storefront_outlined, size: 18),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Business name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomDropdown<String>(
                        label: 'Business Registered State',
                        value: _selectedState,
                        isRequired: true,
                        items: IndianStates.all.map((s) {
                          return DropdownMenuItem(value: s.name, child: Text('${s.name} (${s.code})'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedState = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'GSTIN (Optional)',
                        controller: _gstinController,
                        hintText: '37AAAAA0000A1Z5',
                        prefixIcon: const Icon(Icons.assignment_outlined, size: 18),
                      ),
                      const SizedBox(height: 14),
                    ],

                    CustomTextField(
                      label: 'Email Address',
                      controller: _emailController,
                      isRequired: true,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      label: 'Password',
                      controller: _passwordController,
                      isRequired: true,
                      isPassword: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      validator: (val) => val == null || val.length < 6 ? 'Minimum 6 characters' : null,
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _submit,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(_isLogin ? 'SIGN IN' : 'GET STARTED'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _demoLogin,
                        icon: const Icon(Icons.bolt, color: AppColors.accent),
                        label: const Text('EXPLORE INVOICING DEMO (1-CLICK)'),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
