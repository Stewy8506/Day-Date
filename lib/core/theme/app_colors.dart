import 'package:flutter/material.dart';

/// Design tokens for Day-Date's warm greyscale minimalist aesthetic.
/// Inspired by Swiss & Scandinavian industrial minimalism (Braun, Leica, Teenage Engineering).
abstract class AppColors {
  // ── Canvas & Core Surfaces ────────────────────────────
  static const Color background = Color(0xFF0E0E0D); // Matte carbon-obsidian void
  static const Color backgroundElevated = Color(0xFF131312); // Slightly raised foundation
  
  static const Color surface = Color(0xFF161615); // Flat matte card surface
  static const Color surfaceElevated = Color(0xFF1F1E1D); // Active / hover surface
  static const Color surfaceActive = Color(0xFF282725); // Selected container
  
  // ── Razor-sharp 1px Hairline Borders ──────────────────
  static const Color surfaceBorder = Color(0xFF262623); // Crisp 1px structural hairline
  static const Color surfaceBorderLight = Color(0xFF3D3D38); // Focus / active hairline
  static const Color divider = Color(0xFF1E1E1C);

  // ── Archival Editorial Typography ─────────────────────
  static const Color textPrimary = Color(0xFFF5F3EC); // Warm ivory / parchment text
  static const Color textSecondary = Color(0xFF9E9B91); // Warm stone gray text
  static const Color textTertiary = Color(0xFF636058); // Muted editorial caption
  static const Color textDisabled = Color(0xFF42403B);

  // ── Restrained Semantic Accents ───────────────────────
  static const Color accentWarm = Color(0xFFE09F3E); // Warm ochre for active focus
  static const Color accentWarmSubtle = Color(0x22E09F3E);
  
  static const Color accentTerracotta = Color(0xFFD95D39); // Burnt terracotta for deviations
  static const Color accentTerracottaSubtle = Color(0x22D95D39);
  
  static const Color accentSage = Color(0xFF5B8E7D); // Muted sage for completed & leisure
  static const Color accentSageSubtle = Color(0x225B8E7D);
  
  static const Color accentSteel = Color(0xFF8C8275); // Warm steel for fixed routine anchors
  static const Color accentSteelSubtle = Color(0x188C8275);

  // ── Per-Target Focus Accents ──────────────────────────
  static const Color accentIndigo = Color(0xFF7B8CDE);   // Soft indigo for Freelancing
  static const Color accentIndigoSubtle = Color(0x187B8CDE);
  
  static const Color accentMauve = Color(0xFFBB86A8);    // Dusty mauve for CAT Prep
  static const Color accentMauveSubtle = Color(0x18BB86A8);
  
  static const Color accentTeal = Color(0xFF5BA4A4);     // Muted teal for additional targets
  static const Color accentTealSubtle = Color(0x185BA4A4);

  /// Returns the distinct accent color for a specific target name.
  /// Each target gets a unique color for visual scanning.
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
    // Per-target unique colors
    if (clean.contains('swe') || clean.contains('roadmap')) {
      return accentWarm; // Warm amber
    }
    if (clean.contains('cat') || clean.contains('prep')) {
      return accentMauve; // Dusty mauve
    }
    if (clean.contains('freelanc')) {
      return accentIndigo; // Soft indigo
    }
    if (clean.contains('ece') || clean.contains('upkeep')) {
      return accentTeal; // Muted teal
    }
    // Fallback: hash-based color from palette
    final hash = clean.hashCode.abs() % 4;
    return [accentWarm, accentIndigo, accentMauve, accentTeal][hash];
  }

  /// Returns the subtle background glow for a specific target.
  static Color getTargetGlow(String label) {
    return getTargetColor(label).withValues(alpha: 0.12);
  }
}
