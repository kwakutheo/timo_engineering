import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand Colors (Matching new Black & Gold-Yellow template) ───────────────

  /// Signature bright gold-yellow from the template (#FFCC00)
  static const Color primaryYellow = Color(0xFFFFCC00);

  /// Deep amber-gold for high-contrast text and icons on light surfaces (#C68A00)
  static const Color yellowDark = Color(0xFFC68A00);

  /// Warm amber for buttons, chips, and active highlights (#FFB300)
  static const Color yellowAmber = Color(0xFFFFB300);

  /// Soft warm yellow tint for alternating table rows, card accents (#FFF9E6)
  static const Color yellowLight = Color(0xFFFFF9E6);

  /// Subtle light background for table rows (#FFFDF0)
  static const Color tableRowLight = Color(0xFFFFFDF0);

  /// Sleek charcoal-black matching the "INVOICE" banner (#1A1A1A)
  static const Color primaryBlack = Color(0xFF1A1A1A);

  /// Pure black for logos, headings, and high-contrast text (#000000)
  static const Color black = Color(0xFF000000);

  /// Surface charcoal for dark cards, bottom sheets, and elevated elements (#242424)
  static const Color surfaceCharcoal = Color(0xFF242424);

  // ── UI Neutrals & Semantic Colors ──────────────────────────────────────────

  /// Clean off-white background
  static const Color scaffoldBg = Color(0xFFF8F9FA);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF555555);
  static const Color textLightGrey = Color(0xFF888888);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color borderGrey = Color(0xFFBBBBBB);
  static const Color borderYellow = Color(0xFFFFCC00);
  static const Color success = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  // ── Gradients ─────────────────────────────────────────────────────────────

  /// Sleek dark charcoal-to-black gradient matching the INVOICE banner
  static const LinearGradient blackGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Primary dark gradient
  static const LinearGradient primaryGradient = blackGradient;

  /// Vibrant gold-yellow gradient
  static const LinearGradient yellowGradient = LinearGradient(
    colors: [Color(0xFFFFCC00), Color(0xFFFFB300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── PDF colours as hex int for the pdf package ─────────────────────────────
  static const int pdfYellow = 0xFFFFCC00;
  static const int pdfBlack = 0xFF000000;
  static const int pdfNearBlack = 0xFF1A1A1A;
  static const int pdfTableLight = 0xFFFFF9E6;
  static const int pdfBorderGrey = 0xFFBBBBBB;
  static const int pdfMedGrey = 0xFF555555;
}
