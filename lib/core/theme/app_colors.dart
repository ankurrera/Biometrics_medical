import 'package:flutter/material.dart';

abstract class AppColors {
  // ─────────────────────────────────────────────────────────────────────────
  // SOFT UI / PASTEL PALETTE (Reference Design)
  // ─────────────────────────────────────────────────────────────────────────
  static const Color softPrimary = Color(0xFF8B5CF6);    // Main Purple
  static const Color softPrimaryLight = Color(0xFFA78BFA); // Lighter Purple
  static const Color softBackground = Color(0xFFF8F9FE); // Very light blue-grey tint
  
  static const Color softSurface = Colors.white;
  
  // Feature Colors
  static const Color softPurple = Color(0xFFEBE4FF);     // Light Purple background
  static const Color softBlue = Color(0xFFE0F2FE);       // Light Blue background
  static const Color softPink = Color(0xFFFEE2E2);       // Light Pink background
  static const Color softYellow = Color(0xFFFEF3C7);     // Light Yellow background

  static const Color textMain = Color(0xFF1E293B);       // Dark Slate
  static const Color textSub = Color(0xFF64748B);        // Muted Slate

  static const Color borderSoft = Color(0xFFF1F5F9);
  
  static const Color shadowSoft = Color(0xFFE2E8F0);     // Light shadow

  // ─────────────────────────────────────────────────────────────────────────
  // COMPATIBILITY ALIASES (Mapping Old -> New Theme)
  // ─────────────────────────────────────────────────────────────────────────
  static const Color primary = softPrimary;              // Was Teal, now Purple
  static const Color primaryLight = softPrimaryLight;    // Was Teal 300, now Lighter Purple
  static const Color primaryDark = Color(0xFF7C3AED);    // Violet 600 (Darker than softPrimary)
  static const Color primarySurface = softPurple;        // Was Teal 50, now Light Purple bg

  // ─────────────────────────────────────────────────────────────────────────
  // NEUTRALS & SURFACES
  // ─────────────────────────────────────────────────────────────────────────
  static const Color backgroundLight = softBackground;   // Map active bg to soft
  static const Color surfaceLight = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  static const Color textPrimary = textMain;
  static const Color textSecondary = textSub;
  static const Color textLight = Color(0xFF94A3B8);

  static const Color border = borderSoft;
  static const Color shadow = shadowSoft;

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