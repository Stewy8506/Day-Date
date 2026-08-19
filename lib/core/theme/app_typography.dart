import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:day_date/core/theme/app_colors.dart';

/// Refined typographic design system for Day-Date's warm minimalist aesthetic.
abstract class AppTypography {
  // ── Display & Headings ────────────────────────────────
  static TextStyle heroTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: color,
        height: 1.2,
      );

  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle cardTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  // ── Metadata & Eyebrow Tags ───────────────────────────
  static TextStyle overline({Color color = AppColors.textTertiary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: color,
      );

  static TextStyle badge({Color color = AppColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color,
      );

  // ── Body & Captions ───────────────────────────────────
  static TextStyle body({Color color = AppColors.textSecondary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  static TextStyle bodyMedium({Color color = AppColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle caption({Color color = AppColors.textTertiary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // ── Monospace Precision Timestamps & Numbers ──────────
  static TextStyle monoTime({Color color = AppColors.textSecondary}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle monoNumber({
    Color color = AppColors.textPrimary,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: -0.4,
        color: color,
      );
}
