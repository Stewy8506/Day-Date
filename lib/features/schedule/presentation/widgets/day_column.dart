/// A warm greyscale tactile day capsule in the 7-day selector strip.
library;

import 'package:flutter/material.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class DayColumn extends StatelessWidget {
  final int dayOfWeek;
  final List<TimeBlock> blocks;
  final bool isSelected;
  final VoidCallback onTap;

  const DayColumn({
    super.key,
    required this.dayOfWeek,
    required this.blocks,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayName = kDayNames[dayOfWeek] ?? '';
    final shortName = dayName.length >= 3 ? dayName.substring(0, 3).toUpperCase() : dayName;
    final hasFocus = blocks.any((b) => b.type == TimeBlockType.floating);

    return Tactile(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 46,
        margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : AppColors.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.surfaceBorderLight : AppColors.surfaceBorder,
            width: 1.0,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day Abbreviation in Outfit
              Text(
                shortName,
                style: AppTypography.overline(
                  color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
                ).copyWith(
                  fontSize: 9.0,
                  letterSpacing: 1.1,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),

              // Serif Day Index in Newsreader
              Text(
                '$dayOfWeek',
                style: AppTypography.editorialNumeral(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ).copyWith(height: 1.0),
              ),
              const SizedBox(height: 3),

              // Subtle Status Pip
              Container(
                width: 3.5,
                height: 3.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.accentWarm
                      : (hasFocus ? AppColors.textDisabled : Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
