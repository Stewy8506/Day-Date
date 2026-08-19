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

    // Calculate total scheduled hours for this day
    final totalMinutes = blocks.fold(0, (sum, b) => sum + b.durationMinutes);
    final totalHours = (totalMinutes / 60).toStringAsFixed(1);

    return Tactile(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 58,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceActive : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.textSecondary : AppColors.surfaceBorder,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Day Overline (e.g., "MON")
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  shortName,
                  style: AppTypography.overline(
                    color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
              ),
            ),

            // Number of blocks badge
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.background.withValues(alpha: 0.7),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${blocks.length}',
                  style: AppTypography.monoNumber(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.background : AppColors.textSecondary,
                  ),
                ),
              ),
            ),

            // Scheduled duration in hours
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${totalHours}h',
                  style: AppTypography.monoTime(
                    color: isSelected ? AppColors.textSecondary : AppColors.textTertiary,
                  ).copyWith(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
