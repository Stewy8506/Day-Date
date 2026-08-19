/// Dedicated Weekly Matrix Page — full 7-day grid view of routine structure,
/// day densities, and tap-to-inspect navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class WeeklyMatrixPage extends ConsumerWidget {
  const WeeklyMatrixPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(weeklyScheduleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: scheduleAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 2),
          ),
          error: (e, st) => Center(
            child: Text('Error: $e', style: AppTypography.body(color: AppColors.accentTerracotta)),
          ),
          data: (result) {
            final totalHours = result.allocatedHours.values.fold(0.0, (a, b) => a + b);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'Weekly Matrix',
                    style: AppTypography.editorialHero(color: AppColors.textPrimary),
                  ),
                ),

                // ── Summary Metrics Bar ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL SCHEDULED',
                              style: AppTypography.overline(color: AppColors.textTertiary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${totalHours.toStringAsFixed(1)} Hours',
                              style: AppTypography.sectionTitle(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentWarmSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentWarm.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'BALANCED 7 DAYS',
                            style: AppTypography.overline(color: AppColors.accentWarm),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── 7-Day Matrix List ───────────────────────
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final blocks = result.dailySchedule[day] ?? [];
                      final totalDayMinutes = blocks.fold(0, (sum, b) => sum + b.durationMinutes);
                      final dayName = kDayNames[day] ?? 'Day $day';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Tactile(
                          onTap: () {
                            // Select this day and switch to the Daily tab (tab index 0)
                            ref.read(selectedDayProvider.notifier).state = day;
                            ref.read(currentNavigationIndexProvider.notifier).state = 0;
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Day Header Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.surfaceElevated,
                                              border: Border.all(color: AppColors.surfaceBorder),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              dayName.substring(0, 1),
                                              style: AppTypography.monoNumber(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              dayName,
                                              style: AppTypography.sectionTitle(
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${blocks.length} blocks',
                                          style: AppTypography.caption(color: AppColors.textTertiary),
                                        ),
                                        const SizedBox(width: 5),
                                        Text('•', style: AppTypography.caption(color: AppColors.textTertiary)),
                                        const SizedBox(width: 5),
                                        Text(
                                          formatDuration(totalDayMinutes),
                                          style: AppTypography.monoTime(
                                            color: AppColors.textPrimary,
                                          ).copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 15,
                                          color: AppColors.textTertiary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Block Preview Tags
                                if (blocks.isEmpty)
                                  Text(
                                    'No commitments scheduled',
                                    style: AppTypography.caption(color: AppColors.textTertiary),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: blocks.map((b) {
                                      final isFloating = b.type == TimeBlockType.floating;
                                      final accent = AppColors.getTargetColor(b.label);

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isFloating
                                              ? AppColors.surfaceElevated
                                              : AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isFloating
                                                ? accent.withValues(alpha: 0.3)
                                                : AppColors.surfaceBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: accent,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              b.label,
                                              style: AppTypography.caption(color: AppColors.textSecondary)
                                                  .copyWith(fontSize: 10.5),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${formatDuration(b.durationMinutes)})',
                                              style: AppTypography.monoTime(color: AppColors.textTertiary)
                                                  .copyWith(fontSize: 9.5),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
