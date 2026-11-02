import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryBlueDark = Color(0xFF0D47A1);
  static const Color accentPink = Color(0xFFE91E8C);
  static const Color lightBlue = Color(0xFFBBDEFB);
  static const Color tableRowLight = Color(0xFFE3F2FD);
  static const Color borderBlue = Color(0xFF1565C0);
  static const Color scaffoldBg = Color(0xFFF0F4F8);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGrey = Color(0xFF64748B);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFE91E8C), Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // PDF colours as hex int for the pdf package
  static const int pdfPrimaryBlue = 0xFF1565C0;
  static const int pdfAccentPink = 0xFFE91E8C;
  static const int pdfTableLight = 0xFFE3F2FD;
}
