/// Dedicated Daily Schedule Page — immersive day timeline view with day picker,
/// quick college off toggle, and full-bleed block timeline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/presentation/widgets/add_deviation_sheet.dart';
import 'package:day_date/features/schedule/presentation/widgets/day_column.dart';
import 'package:day_date/features/schedule/presentation/widgets/hourly_timeline_view.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class DailySchedulePage extends ConsumerWidget {
  const DailySchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(weeklyScheduleProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final deviationsAsync = ref.watch(rawDeviationsProvider);

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
            final dayBlocks = result.dailySchedule[selectedDay] ?? [];
            final totalMinutes = dayBlocks.fold(0, (sum, b) => sum + b.durationMinutes);
            final dayName = kDayNames[selectedDay] ?? 'Day $selectedDay';
            final isWeekday = selectedDay >= kMonday && selectedDay <= kFriday;

            // Check if this weekday has a college cancellation deviation
            final deviations = deviationsAsync.value ?? [];
            final isCollegeOff = deviations.any(
              (d) => d.type == DeviationType.collegeCancellation && d.dayOfWeek == selectedDay,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Top Title & Quick Action ───────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TIMELINE VIEW',
                            style: AppTypography.overline(color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Daily Schedule',
                            style: AppTypography.heroTitle(),
                          ),
                        ],
                      ),
                      // Tactile Add Override Button
                      Tactile(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const AddDeviationSheet(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 16, color: AppColors.textPrimary),
                              const SizedBox(width: 4),
                              Text(
                                'Override',
                                style: AppTypography.caption(color: AppColors.textPrimary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 2. Horizontal 7-Day Selector Strip ───────
                SizedBox(
                  height: 104,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      return DayColumn(
                        dayOfWeek: day,
                        blocks: result.dailySchedule[day] ?? [],
                        isSelected: day == selectedDay,
                        onTap: () {
                          ref.read(selectedDayProvider.notifier).state = day;
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // ── 3. Active Day Subheader & College Toggle ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayName.toUpperCase(),
                              style: AppTypography.sectionTitle(color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dayBlocks.length} blocks • ${formatDuration(totalMinutes)} scheduled',
                              style: AppTypography.caption(color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // One-tap College Off toggle for weekdays
                      if (isWeekday)
                        Tactile(
                          onTap: () {
                            final now = DateTime.now();
                            final daysUntil = (selectedDay - now.weekday) % 7;
                            final targetDate = DateTime(now.year, now.month, now.day + daysUntil);

                            ref.read(setCollegeStatusProvider)(
                              targetDate,
                              isAttending: isCollegeOff, // toggle: if off, set to attending
                              strategy: OffDayStrategy.accelerateWeek,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCollegeOff
                                  ? AppColors.accentTerracottaSubtle
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCollegeOff
                                    ? AppColors.accentTerracotta
                                    : AppColors.surfaceBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCollegeOff
                                      ? Icons.school_rounded
                                      : Icons.school_outlined,
                                  size: 13,
                                  color: isCollegeOff
                                      ? AppColors.accentTerracotta
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isCollegeOff ? 'College Off' : 'Attending',
                                  style: AppTypography.overline(
                                    color: isCollegeOff
                                        ? AppColors.accentTerracotta
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── 4. Hourly Continuous Timeline ───────────
                Expanded(
                  child: HourlyTimelineView(
                    dayOfWeek: selectedDay,
                    blocks: dayBlocks,
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
