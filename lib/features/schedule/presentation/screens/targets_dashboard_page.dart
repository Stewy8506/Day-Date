/// Dedicated Targets & Goals Dashboard — inspects floating goals, weekly progress,
/// affinity windows, daily caps, and 7-day distribution.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';

class TargetsDashboardPage extends ConsumerWidget {
  const TargetsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(rawTargetsProvider);
    final scheduleAsync = ref.watch(weeklyScheduleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: targetsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 2),
          ),
          error: (e, st) => Center(
            child: Text('Error: $e', style: AppTypography.body(color: AppColors.accentTerracotta)),
          ),
          data: (targets) {
            return scheduleAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 2),
              ),
              error: (e, st) => Center(
                child: Text('Error: $e', style: AppTypography.body(color: AppColors.accentTerracotta)),
              ),
              data: (result) {
                final totalRequested = targets.fold(0.0, (sum, t) => sum + t.weeklyHours);
                final totalAllocated = result.allocatedHours.values.fold(0.0, (sum, h) => sum + h);
                final overallPercent = totalRequested > 0 ? (totalAllocated / totalRequested).clamp(0.0, 1.0) : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header Bar ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FLOATING TARGETS',
                            style: AppTypography.overline(color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Goals & Quotas',
                            style: AppTypography.heroTitle(),
                          ),
                        ],
                      ),
                    ),

                    // ── Total Quota Card ────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'OVERALL WEEKLY FULFILLMENT',
                                  style: AppTypography.overline(color: AppColors.textTertiary),
                                ),
                                Text(
                                  '${(overallPercent * 100).toInt()}%',
                                  style: AppTypography.monoNumber(
                                    fontSize: 14,
                                    color: AppColors.accentWarm,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${totalAllocated.toStringAsFixed(1)}h / ${totalRequested.toStringAsFixed(1)}h',
                              style: AppTypography.sectionTitle(color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 10),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: overallPercent,
                                backgroundColor: AppColors.surfaceElevated,
                                valueColor: const AlwaysStoppedAnimation(AppColors.accentWarm),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Target Cards List ───────────────────────
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        itemCount: targets.length,
                        itemBuilder: (context, index) {
                          final target = targets[index];
                          final allocated = result.allocatedHours[target.id] ?? 0.0;
                          final percent = target.weeklyHours > 0
                              ? (allocated / target.weeklyHours).clamp(0.0, 1.0)
                              : 0.0;

                          // Compute which days have this target allocated
                          final dayAllocations = <int, int>{};
                          for (int day = kMonday; day <= kSunday; day++) {
                            final minutes = (result.dailySchedule[day] ?? [])
                                .where((b) => b.parentTargetId == target.id)
                                .fold(0, (sum, b) => sum + b.durationMinutes);
                            if (minutes > 0) dayAllocations[day] = minutes;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title + Priority Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceElevated,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: AppColors.surfaceBorder),
                                              ),
                                              child: Text(
                                                'P${target.priority}',
                                                style: AppTypography.overline(color: AppColors.accentWarm),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                target.name,
                                                style: AppTypography.cardTitle(color: AppColors.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${allocated.toStringAsFixed(1)} / ${target.weeklyHours.toStringAsFixed(1)}h',
                                        style: AppTypography.monoNumber(
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      backgroundColor: AppColors.surfaceElevated,
                                      valueColor: const AlwaysStoppedAnimation(AppColors.accentWarm),
                                      minHeight: 4,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Constraint Metadata Pills
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.surfaceBorder),
                                        ),
                                        child: Text(
                                          _affinityName(target.affinity),
                                          style: AppTypography.caption(color: AppColors.textSecondary)
                                              .copyWith(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.surfaceBorder),
                                        ),
                                        child: Text(
                                          'Cap: ${target.dailyCapHours.toStringAsFixed(1)}h/day',
                                          style: AppTypography.caption(color: AppColors.textTertiary)
                                              .copyWith(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // 7-day distribution mini tags
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: List.generate(7, (i) {
                                      final day = i + 1;
                                      final dayName = (kDayNames[day] ?? '').substring(0, 3).toUpperCase();
                                      final mins = dayAllocations[day] ?? 0;
                                      final isAllocated = mins > 0;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAllocated ? AppColors.surfaceElevated : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isAllocated ? AppColors.accentWarm.withValues(alpha: 0.4) : AppColors.divider,
                                          ),
                                        ),
                                        child: Text(
                                          isAllocated ? '$dayName ${formatDuration(mins)}' : dayName,
                                          style: AppTypography.monoTime(
                                            color: isAllocated ? AppColors.textPrimary : AppColors.textDisabled,
                                          ).copyWith(fontSize: 9.5),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _affinityName(TimeAffinity a) {
    switch (a) {
      case TimeAffinity.morning:
        return 'Morning (7:30 AM – 12 PM)';
      case TimeAffinity.afternoon:
        return 'Afternoon (12 PM – 7 PM)';
      case TimeAffinity.lateNight:
        return 'Late Night (9:30 PM – 12 AM)';
      case TimeAffinity.flexible:
        return 'Flexible Window';
    }
  }
}
