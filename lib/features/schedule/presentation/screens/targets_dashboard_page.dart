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
import 'package:day_date/features/schedule/presentation/widgets/edit_target_sheet.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FLOATING TARGETS',
                                style: AppTypography.overline(color: AppColors.textTertiary),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Goals & Quotas',
                                style: AppTypography.editorialHero(color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          Tactile(
                            onTap: () => EditTargetSheet.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, size: 14, color: AppColors.textPrimary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'New Goal',
                                    style: AppTypography.badge(color: AppColors.textPrimary).copyWith(
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Total Quota Card ────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'WEEKLY FULFILLMENT',
                                  style: AppTypography.overline(color: AppColors.textTertiary),
                                ),
                                Text(
                                  '${(overallPercent * 100).toInt()}%',
                                  style: AppTypography.monoNumber(
                                    fontSize: 13,
                                    color: AppColors.accentWarm,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalAllocated.toStringAsFixed(1)}h / ${totalRequested.toStringAsFixed(1)}h scheduled',
                              style: AppTypography.editorialDate(color: AppColors.textPrimary).copyWith(
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: overallPercent,
                                backgroundColor: AppColors.surfaceElevated,
                                valueColor: const AlwaysStoppedAnimation(AppColors.accentWarm),
                                minHeight: 3.5,
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
                          final romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
                          final romanIndex = index < romanNumerals.length ? romanNumerals[index] : '${index + 1}';
                          final completions = ref.watch(rawTaskCompletionsProvider).value ?? [];
                          final extraOvertimeMinutes = completions
                              .where((c) => c.targetId == target.id && c.actualMinutes > c.scheduledMinutes)
                              .fold(0, (sum, c) => sum + (c.actualMinutes - c.scheduledMinutes));
                          final allocated = (result.allocatedHours[target.id] ?? 0.0) + (extraOvertimeMinutes / 60.0);
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
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Tactile(
                              onTap: () => EditTargetSheet.show(context, target: target),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
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
                                              Text(
                                                '$romanIndex.',
                                                style: AppTypography.editorialNumeral(
                                                  color: AppColors.textTertiary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
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
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${allocated.toStringAsFixed(1)} / ${target.weeklyHours.toStringAsFixed(1)}h',
                                              style: AppTypography.monoNumber(
                                                fontSize: 12.5,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.edit_outlined, size: 13, color: AppColors.textTertiary),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Progress Bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        backgroundColor: AppColors.surfaceElevated,
                                        valueColor: const AlwaysStoppedAnimation(AppColors.accentWarm),
                                        minHeight: 3,
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // Constraint Metadata Pills
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceElevated,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: AppColors.surfaceBorder),
                                          ),
                                          child: Text(
                                            _affinityName(target.affinity).toUpperCase(),
                                            style: AppTypography.overline(color: AppColors.textSecondary)
                                                .copyWith(fontSize: 8.5),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceElevated,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: AppColors.surfaceBorder),
                                          ),
                                          child: Text(
                                            'CAP ${target.dailyCapHours.toStringAsFixed(1)}H/DAY',
                                            style: AppTypography.overline(color: AppColors.textTertiary)
                                                .copyWith(fontSize: 8.5),
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
