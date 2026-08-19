import 'package:flutter/material.dart';

/// Design tokens for Day-Date's warm greyscale minimalist aesthetic.
/// Inspired by Swiss & Scandinavian industrial minimalism (Braun, Leica, Teenage Engineering).
abstract class AppColors {
  // ── Canvas & Core Surfaces ────────────────────────────
  static const Color background = Color(0xFF121211); // Deep warm bistre / charcoal
  static const Color backgroundElevated = Color(0xFF161514); // Elevated layer
  
  static const Color surface = Color(0xFF1A1918); // Warm graphite card surface
  static const Color surfaceElevated = Color(0xFF242321); // Active / hover surface
  static const Color surfaceActive = Color(0xFF2C2A27); // Selected container
  
  // ── Hairline Borders & Dividers ───────────────────────
  static const Color surfaceBorder = Color(0xFF282623); // Subtle hairline
  static const Color surfaceBorderLight = Color(0xFF383531); // Focus hairline
  static const Color divider = Color(0xFF201E1C);

  // ── Warm Typography ───────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F3EF); // Warm alabaster / bone
  static const Color textSecondary = Color(0xFFA39E93); // Warm stone gray
  static const Color textTertiary = Color(0xFF6E695F); // Warm muted clay
  static const Color textDisabled = Color(0xFF4A463F);

  // ── Restrained Semantic Accents (Used Sparingly) ───────
  static const Color accentWarm = Color(0xFFE59500); // Warm amber / ochre for active focus
  static const Color accentWarmSubtle = Color(0x22E59500);
  
  static const Color accentTerracotta = Color(0xFFD9534F); // Burnt terracotta for deviations
  static const Color accentTerracottaSubtle = Color(0x22D9534F);
  
  static const Color accentSage = Color(0xFF5E9C76); // Muted sage for free leisure time
  static const Color accentSageSubtle = Color(0x225E9C76);
  
  static const Color accentSteel = Color(0xFF88847C); // Brushed steel for fixed routine anchors
  static const Color accentSteelSubtle = Color(0x1888847C);

  /// Returns the subtle accent color for a specific block or target name.
  static Color getTargetColor(String label) {
    final clean = label.trim().toLowerCase();
    if (clean.contains('college') || clean.contains('gym') || clean.contains('commute')) {
      return accentSteel;
    }
    if (clean.contains('free time')) {
      return accentSage;
    }
    if (clean.contains('outing') || clean.contains('doctor') || clean.contains('deviation')) {
      return accentTerracotta;
    }
    // Study and deep work targets use warm amber / ochre
    return accentWarm;
  }

  /// Returns the subtle background glow for a specific target.
  static Color getTargetGlow(String label) {
    return getTargetColor(label).withValues(alpha: 0.12);
  }
}
