/// A warm greyscale minimalist card for a single scheduled time block.
library;

import 'package:flutter/material.dart';

import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class TimeBlockCard extends StatelessWidget {
  final TimeBlock block;
  final bool isFirst;
  final bool isLast;

  const TimeBlockCard({
    super.key,
    required this.block,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    final isFloating = block.type == TimeBlockType.floating;
    final isDeviation = block.type == TimeBlockType.deviation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Tactile(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDeviation
                  ? AppColors.accentTerracotta.withValues(alpha: 0.4)
                  : AppColors.surfaceBorder,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Minimalist Left Accent Node / Indicator
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),

                // Block Information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Tag
                      Row(
                        children: [
                          Text(
                            _categoryTag,
                            style: AppTypography.overline(
                              color: isDeviation
                                  ? AppColors.accentTerracotta
                                  : isFloating
                                      ? AppColors.accentWarm
                                      : AppColors.textTertiary,
                            ),
                          ),
                          if (block.label.contains('Free Time')) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.accentSageSubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'LEISURE',
                                style: AppTypography.overline(color: AppColors.accentSage),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Block Title
                      Text(
                        block.label,
                        style: AppTypography.cardTitle(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Monospace Time Range
                      Text(
                        '${formatMinutes(block.startMinutes)}  —  ${formatMinutes(block.endMinutes)}',
                        style: AppTypography.monoTime(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text(
                    formatDuration(block.durationMinutes),
                    style: AppTypography.monoTime(
                      color: AppColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _accentColor {
    switch (block.type) {
      case TimeBlockType.fixed:
        return AppColors.accentSteel;
      case TimeBlockType.floating:
        return AppColors.accentWarm;
      case TimeBlockType.deviation:
        if (block.label.contains('Free Time')) return AppColors.accentSage;
        return AppColors.accentTerracotta;
    }
  }

  String get _categoryTag {
    switch (block.type) {
      case TimeBlockType.fixed:
        return 'ANCHOR';
      case TimeBlockType.floating:
        return 'FOCUS';
      case TimeBlockType.deviation:
        if (block.label.contains('Free Time')) return 'FREE TIME';
        return 'OVERRIDE';
    }
  }
}
