import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:day_date/core/theme/app_colors.dart';

/// Editorial Typographic Design System for Day-Date.
/// Combines the geometric humanist clarity of Outfit with the high-end
/// editorial elegance of Newsreader serif.
abstract class AppTypography {
  // ── Editorial Serif Accents (Newsreader) ───────────────
  static TextStyle editorialHero({Color color = AppColors.textPrimary}) =>
      GoogleFonts.newsreader(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.4,
        color: color,
        height: 1.15,
      );

  static TextStyle editorialTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.newsreader(
        fontSize: 19,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle editorialDate({Color color = AppColors.textPrimary}) =>
      GoogleFonts.newsreader(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle editorialNumeral({
    Color color = AppColors.textPrimary,
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
  }) =>
      GoogleFonts.newsreader(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  static TextStyle editorialSubtext({Color color = AppColors.textSecondary}) =>
      GoogleFonts.newsreader(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: color,
      );

  static TextStyle headerSubtext({Color color = AppColors.textSecondary}) =>
      GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: color,
      );

  // ── Geometric Structure & UI (Outfit) ─────────────────
  static TextStyle heroTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
        height: 1.2,
      );

  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  static TextStyle cardTitle({Color color = AppColors.textPrimary}) =>
      GoogleFonts.outfit(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: color,
      );

  // ── Metadata & Eyebrow Tags ───────────────────────────
  static TextStyle overline({Color color = AppColors.textTertiary}) =>
      GoogleFonts.outfit(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: color,
      );

  static TextStyle badge({Color color = AppColors.textPrimary}) =>
      GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      );

  // ── Body & Captions (Outfit) ───────────────────────────
  static TextStyle body({Color color = AppColors.textSecondary}) =>
      GoogleFonts.outfit(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.4,
      );

  static TextStyle bodyMedium({Color color = AppColors.textPrimary}) =>
      GoogleFonts.outfit(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle caption({Color color = AppColors.textTertiary}) =>
      GoogleFonts.outfit(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // ── Time & Numerical Telemetry (Outfit Tabular) ────────
  static TextStyle monoTime({Color color = AppColors.textSecondary}) =>
      GoogleFonts.outfit(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: color,
      );

  static TextStyle monoNumber({
    Color color = AppColors.textPrimary,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
  }) =>
      GoogleFonts.outfit(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: -0.2,
        color: color,
      );
}
