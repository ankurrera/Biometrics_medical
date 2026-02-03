import 'package:flutter/material.dart';

/// CareSync Color Palette
/// 
/// A medical-focused color system with:
/// - Teal primary for trust and healthcare association
/// - Coral accent for urgency and emergency actions
/// - Clean, accessible contrast ratios
abstract class AppColors {
  // ─────────────────────────────────────────────────────────────────────────
  // PRIMARY COLORS - Teal (Healthcare, Trust, Calm)
  // ─────────────────────────────────────────────────────────────────────────
  
  static const Color primary = Color(0xFF0D9488);        // Teal 600
  static const Color primaryLight = Color(0xFF5EEAD4);   // Teal 300
  static const Color primaryDark = Color(0xFF115E59);    // Teal 800
  static const Color primarySurface = Color(0xFFCCFBF1); // Teal 100

  // ─────────────────────────────────────────────────────────────────────────
  // SECONDARY COLORS - Slate (Professional, Neutral)
  // ─────────────────────────────────────────────────────────────────────────
  
  static const Color secondary = Color(0xFF475569);      // Slate 600
  static const Color secondaryLight = Color(0xFF94A3B8); // Slate 400
  static const Color secondaryDark = Color(0xFF1E293B);  // Slate 800

  // ─────────────────────────────────────────────────────────────────────────
  // ACCENT COLORS - Coral (Urgency, Emergency, Action)
  // ─────────────────────────────────────────────────────────────────────────
  
  static const Color accent = Color(0xFFF97316);         // Orange 500
  static const Color accentLight = Color(0xFFFED7AA);    // Orange 200
  static const Color accentDark = Color(0xFFEA580C);     // Orange 600

  // ─────────────────────────────────────────────────────────────────────────
  // ROLE-SPECIFIC COLORS
  // ─────────────────────────────────────────────────────────────────────────
  
  static const Color patient = Color(0xFF0EA5E9);        // Sky 500
  static const Color doctor = Color(0xFF8B5CF6);         // Violet 500
  static const Color pharmacist = Color(0xFF10B981);     // Emerald 500
  static const Color firstResponder = Color(0xFFEF4444); // Red 500

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC COLORS
  // ─────────────────────────────────────────────────────────────────────────
  
  static const Color success = Color(0xFF22C55E);        // Green 500
  static const Color warning = Color(0xFFF59E0B);        // Amber 500
  static const Color error = Color(0xFFEF4444);          // Red 500
  static const Color info = Color(0xFF3B82F6);           // Blue 500

  static const Color successLight = Color(0xFFDCFCE7);   // Green 100
  static const Color warningLight = Color(0xFFFEF3C7);   // Amber 100
  static const Color errorLight = Color(0xFFFEE2E2);     // Red 100
  static const Color infoLight = Color(0xFFDBEAFE);      // Blue 100

  // ─────────────────────────────────────────────────────────────────────────
  // LIGHT THEME COLORS
  // ─────────────────────────────────────────────────────────────────────────
  
  static const Color backgroundLight = Color(0xFFF8FAFC);   // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);      // White
  static const Color borderLight = Color(0xFFE2E8F0);       // Slate 200
  static const Color textPrimaryLight = Color(0xFF0F172A);  // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B);// Slate 500
  static const Color textSecondary = Color(0xFF64748B);     // Alias for textSecondaryLight

  // ─────────────────────────────────────────────────────────────────────────
  // DARK THEME COLORS
  // ─────────────────────────────────────────────────────────────────────────
  
  static const Color backgroundDark = Color(0xFF0F172A);    // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B);       // Slate 800
  static const Color borderDark = Color(0xFF334155);        // Slate 700
  static const Color textPrimaryDark = Color(0xFFF1F5F9);   // Slate 100
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
}

