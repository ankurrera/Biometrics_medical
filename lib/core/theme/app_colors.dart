import 'package:flutter/material.dart';

abstract class AppColors {
  // ─────────────────────────────────────────────────────────────────────────
  // MODERN BRAND COLORS (Soft UI / Dribbble Style)
  // ─────────────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF14B8A6);        // Teal 500
  static const Color primaryLight = Color(0xFF5EEAD4);   // Teal 300
  static const Color primaryDark = Color(0xFF0F766E);    // Teal 700
  static const Color primarySurface = Color(0xFFF0FDFA); // Teal 50

  // ─────────────────────────────────────────────────────────────────────────
  // NEUTRALS & SURFACES
  // ─────────────────────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8FAFC);   // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);      // Pure White
  static const Color surfaceVariant = Color(0xFFF1F5F9);    // Slate 100

  static const Color textPrimary = Color(0xFF1E293B);       // Slate 800
  static const Color textSecondary = Color(0xFF64748B);     // Slate 500
  static const Color textLight = Color(0xFF94A3B8);         // Slate 400

  static const Color border = Color(0xFFE2E8F0);            // Slate 200
  static const Color shadow = Color(0xFF64748B);            // For custom shadows

  // ─────────────────────────────────────────────────────────────────────────
  // LEGACY ALIASES & ROLE COLORS (Restored for Compatibility)
  // ─────────────────────────────────────────────────────────────────────────

  // Roles - Mapped to modern pastel/vibrant tones
  static const Color patient = Color(0xFF38BDF8);        // Sky 400
  static const Color doctor = Color(0xFF8B5CF6);         // Violet 500
  static const Color pharmacist = Color(0xFF10B981);     // Emerald 500
  static const Color firstResponder = Color(0xFFEF4444); // Red 500

  // Semantics
  static const Color success = Color(0xFF22C55E);        // Green 500
  static const Color warning = Color(0xFFF59E0B);        // Amber 500
  static const Color error = Color(0xFFEF4444);          // Red 500
  static const Color info = Color(0xFF3B82F6);           // Blue 500

  // Light variants (for backgrounds)
  static const Color successLight = Color(0xFFDCFCE7);   // Green 100
  static const Color warningLight = Color(0xFFFEF3C7);   // Amber 100
  static const Color errorLight = Color(0xFFFEE2E2);     // Red 100
  static const Color infoLight = Color(0xFFDBEAFE);      // Blue 100

  // Aliases for refactored code
  static const Color secondary = Color(0xFF64748B);      // Slate 500 (Matches textSecondary)
  static const Color accent = Color(0xFFFB923C);         // Orange 400
}