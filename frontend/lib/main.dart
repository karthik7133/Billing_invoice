import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/business_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/product_provider.dart';
import 'providers/invoice_provider.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient().init();
  runApp(const GstBillingApp());
}

class GstBillingApp extends StatelessWidget {
  const GstBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuthStatus()),
        ChangeNotifierProvider(create: (_) => BusinessProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
      ],
      child: MaterialApp(
        title: 'GST Billing & Invoice App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _AppRouter(),
      ),
    );
  }
}

/// Watches AuthProvider and routes to the correct screen
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // While checking stored token, show a simple splash
    if (!auth.hasCheckedAuth) {
      return const _SplashScreen();
    }

    if (auth.isAuthenticated) {
      return const MainNavigationScreen();
    }

    return const _OnboardingOrLogin();
  }
}

/// Decides whether to show onboarding (first launch) or login directly
class _OnboardingOrLogin extends StatefulWidget {
  const _OnboardingOrLogin();

  @override
  State<_OnboardingOrLogin> createState() => _OnboardingOrLoginState();
}

class _OnboardingOrLoginState extends State<_OnboardingOrLogin> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    if (mounted) setState(() => _showOnboarding = !done);
  }

  void _onOnboardingFinished() {
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) return const _SplashScreen();
    if (_showOnboarding!) {
      return OnboardingScreen(onFinished: _onOnboardingFinished);
    }
    return const LoginScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 20),
            const Text(
              'GST Billing',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Professional Invoicing Engine',
              style: TextStyle(fontSize: 13, color: Colors.white60),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
