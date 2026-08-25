import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF1E3A8A); // Deep Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF172554);
  static const Color primaryGradientStart = Color(0xFF1E3A8A);
  static const Color primaryGradientEnd = Color(0xFF2563EB);

  // Secondary & Accents
  static const Color secondary = Color(0xFF0D9488); // Teal
  static const Color secondaryLight = Color(0xFF14B8A6);
  static const Color accent = Color(0xFFF59E0B); // Amber / Gold
  static const Color electricBlue = Color(0xFF2563EB);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textInverse = Color(0xFFFFFFFF);

  // Vyapar / Billing Brand & Action Colors
  static const Color vyaparPink = Color(0xFFE51A4B); // Vibrant pink/crimson FAB & active pill
  static const Color vyaparPinkLight = Color(0xFFFFF0F4);
  static const Color vyaparBlue = Color(0xFF1E88E5);
  static const Color vyaparBlueLight = Color(0xFFE8F1FC);
  static const Color receivableGreen = Color(0xFF059669); // "You'll Get" green
  static const Color receivableGreenLight = Color(0xFFECFDF5);
  static const Color payableRed = Color(0xFFE11D48); // "You'll Give" red
  static const Color payableRedLight = Color(0xFFFFECEF);
  static const Color unpaidOrange = Color(0xFFD97706);
  static const Color unpaidOrangeLight = Color(0xFFFEF3C7);
  static const Color paidGreen = Color(0xFF10B981);
  static const Color paidGreenLight = Color(0xFFD1FAE5);
  static const Color backgroundSoft = Color(0xFFF4F7FB);

  // Cloud Backend Status Colors
  static const Color cloudOnline = Color(0xFF10B981);
  static const Color cloudOnlineBg = Color(0xFFECFDF5);
  static const Color cloudWaking = Color(0xFFF59E0B);
  static const Color cloudWakingBg = Color(0xFFFFFBEB);
  static const Color cloudOffline = Color(0xFFEF4444);
  static const Color cloudOfflineBg = Color(0xFFFEF2F2);

  // Status & Semantic Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6); // Blue 500
  static const Color infoBg = Color(0xFFEFF6FF);

  // Badge Colors for Invoice Status
  static const Color statusPaidText = Color(0xFF065F46);
  static const Color statusPaidBg = Color(0xFFD1FAE5);

  static const Color statusUnpaidText = Color(0xFF9A3412);
  static const Color statusUnpaidBg = Color(0xFFFFEDD5);

  static const Color statusPartialText = Color(0xFF92400E);
  static const Color statusPartialBg = Color(0xFFFEF3C7);

  static const Color statusDraftText = Color(0xFF374151);
  static const Color statusDraftBg = Color(0xFFF3F4F6);

  static const Color statusCancelledText = Color(0xFF4B5563);
  static const Color statusCancelledBg = Color(0xFFE5E7EB);
}
