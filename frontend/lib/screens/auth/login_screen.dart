import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/indian_states.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/backend_sync_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/cloud_server_status_pill.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _obscurePassword = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();

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
    debugPrint('[LoginScreen] _submit() clicked. Mode: ${_isLogin ? "LOGIN" : "REGISTER"}');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[LoginScreen] Form validation failed');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success;
    if (_isLogin) {
      debugPrint('[LoginScreen] Attempting login with email: ${_emailController.text.trim()}');
      success = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } else {
      debugPrint('[LoginScreen] Attempting register for: ${_nameController.text.trim()} (${_emailController.text.trim()})');
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

    debugPrint('[LoginScreen] Result success=$success, error=${authProvider.errorMessage}');

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Something went wrong. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (success && mounted) {
      // Auto-trigger sync on login
      final busP = Provider.of<BusinessProvider>(context, listen: false);
      final custP = Provider.of<CustomerProvider>(context, listen: false);
      final prodP = Provider.of<ProductProvider>(context, listen: false);
      final invP = Provider.of<InvoiceProvider>(context, listen: false);

      BackendSyncService.instance.forceSync(
        authProvider: authProvider,
        businessProvider: busP,
        customerProvider: custP,
        productProvider: prodP,
        invoiceProvider: invP,
      );
    }
  }

  void _demoLogin() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.loginAsDemo();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Premium Gradient Header with App Branding & Cloud Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 60, bottom: 32, left: 24, right: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                      ),
                      const CloudServerStatusPill(compact: true),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'GST Billing & Invoice',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Fast, compliant, and professional invoicing for your business',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Auth Card Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Pill Switcher (Sign In vs Register Business)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isLogin = true),
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isLogin ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _isLogin
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontWeight: _isLogin ? FontWeight.w800 : FontWeight.w600,
                                        color: _isLogin ? AppColors.electricBlue : AppColors.textSecondary,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isLogin = false),
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isLogin ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !_isLogin
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Register Business',
                                      style: TextStyle(
                                        fontWeight: !_isLogin ? FontWeight.w800 : FontWeight.w600,
                                        color: !_isLogin ? AppColors.electricBlue : AppColors.textSecondary,
                                        fontSize: 13.5,
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
                        isPassword: _obscurePassword,
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (val) => val == null || val.length < 6 ? 'Minimum 6 characters' : null,
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: authProvider.isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    ),
                                    SizedBox(width: 10),
                                    Text('CONNECTING...', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                )
                              : Text(
                                  _isLogin ? 'SIGN IN' : 'GET STARTED',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _demoLogin,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.bolt, color: AppColors.accent, size: 20),
                          label: const Text(
                            'EXPLORE INVOICING DEMO (1-CLICK)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }
}
