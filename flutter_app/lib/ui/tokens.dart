import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours taken from the Figma file
/// "Secure QR Access & Identity Verification — Mobile App".
abstract final class AppColors {
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const placeholder = Color(0xFF9CA3AF);
  static const border = Color(0xFFE2E8F0);
  static const fieldFill = Color(0xFFF8FAFC);
  static const demoFill = Color(0xFFF1F4F8);
  static const track = Color(0xFFE6EAF0);
  static const qrInk = Color(0xFF1A1A1F);

  static const primary = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const disabled = Color(0xFFB2BFD1);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
  static const green = Color(0xFF16A34A);

  // Soft circle / pill backgrounds behind status icons.
  static const primarySoft = Color(0xFFE5EEFD);
  static const redSoft = Color(0xFFFEE9E9);
  static const redFieldFill = Color(0xFFFEECEC);
  static const amberSoft = Color(0xFFFEF1E0);
  static const greenSoft = Color(0xFFE0F5E7);
}

/// Text styles (Inter) used across the screens.
abstract final class AppText {
  static TextStyle _inter(double size, FontWeight weight, Color color) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle get title => _inter(24, FontWeight.w700, AppColors.textPrimary);
  static TextStyle get stateTitle => _inter(22, FontWeight.w700, AppColors.textPrimary);
  static TextStyle get name => _inter(16, FontWeight.w600, AppColors.textPrimary);
  static TextStyle get brand => _inter(15, FontWeight.w600, AppColors.textPrimary);
  static TextStyle get button => _inter(14, FontWeight.w600, Colors.white);
  static TextStyle get body => _inter(13, FontWeight.w400, AppColors.textSecondary);
  static TextStyle get input => _inter(13, FontWeight.w400, AppColors.textPrimary);
  static TextStyle get hint => _inter(13, FontWeight.w400, AppColors.placeholder);
  static TextStyle get link => _inter(13, FontWeight.w500, AppColors.primary);
  static TextStyle get label => _inter(12, FontWeight.w500, AppColors.textSecondary);
  static TextStyle get small => _inter(12, FontWeight.w400, AppColors.textSecondary);
  static TextStyle get caption => _inter(11, FontWeight.w400, AppColors.textSecondary);
  static TextStyle get footnote => _inter(11, FontWeight.w400, AppColors.placeholder);
  static TextStyle inter(double size, FontWeight weight, Color color) => _inter(size, weight, color);
}

ThemeData buildAppTheme() {
  // Use Inter as the app-wide font family. (Avoids GoogleFonts.interTextTheme,
  // whose TextTheme type clashes with this Flutter version.)
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
    scaffoldBackgroundColor: Colors.white,
    fontFamily: GoogleFonts.inter().fontFamily,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
