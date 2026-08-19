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
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
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
            final floatingBlocks = dayBlocks.where((b) => b.type == TimeBlockType.floating).toList();
            final scheduledMinutes = floatingBlocks.fold(0, (sum, b) => sum + b.durationMinutes);
            final focusCount = floatingBlocks.length;
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
                // ── 1. Unified Editorial Header & Actions ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayName,
                            style: AppTypography.editorialHero(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${formatDuration(scheduledMinutes)} scheduled · $focusCount focus',
                            style: AppTypography.headerSubtext(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // One-tap College Off toggle for weekdays
                          if (isWeekday) ...[
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
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isCollegeOff
                                      ? AppColors.accentTerracottaSubtle
                                      : AppColors.surface,
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
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCollegeOff
                                            ? AppColors.accentTerracotta
                                            : AppColors.accentSage,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isCollegeOff ? 'Off' : 'College',
                                      style: AppTypography.badge(
                                        color: isCollegeOff
                                            ? AppColors.accentTerracotta
                                            : AppColors.textPrimary,
                                      ).copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

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
                                  const SizedBox(width: 3),
                                  Text(
                                    'Override',
                                    style: AppTypography.badge(color: AppColors.textPrimary).copyWith(
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── 2. Integrated 7-Day Date Strip ──────────
                SizedBox(
                  height: 52,
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

                const SizedBox(height: 8),


                // ── 3. Hourly Continuous Timeline (Fluid Day Transition) ───
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.02),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey(selectedDay),
                      child: HourlyTimelineView(
                        dayOfWeek: selectedDay,
                        blocks: dayBlocks,
                      ),
                    ),
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
