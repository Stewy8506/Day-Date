/// Dedicated Monthly Schedule Page — monthly view of per-week hours spent,
/// target distribution, month calendar heatmap, and tap-to-inspect navigation.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/task_completion.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

/// Represents a single calendar week within the month.
class _MonthWeekData {
  final int weekIndex;
  final DateTime startOfWeek;
  final DateTime endOfWeek;
  final List<DateTime> daysInMonth;
  final double scheduledHours;
  final double completedHours;
  final Map<String, double> targetHours; // targetId/name -> hours
  final bool isCurrentWeek;
  final bool isPastWeek;

  const _MonthWeekData({
    required this.weekIndex,
    required this.startOfWeek,
    required this.endOfWeek,
    required this.daysInMonth,
    required this.scheduledHours,
    required this.completedHours,
    required this.targetHours,
    required this.isCurrentWeek,
    required this.isPastWeek,
  });
}

class MonthlySchedulePage extends ConsumerStatefulWidget {
  const MonthlySchedulePage({super.key});

  @override
  ConsumerState<MonthlySchedulePage> createState() => _MonthlySchedulePageState();
}

class _MonthlySchedulePageState extends ConsumerState<MonthlySchedulePage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(weeklyScheduleProvider);
    final completionsAsync = ref.watch(rawTaskCompletionsProvider);
    final completions = completionsAsync.value ?? [];

    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

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
            // Compute monthly weeks breakdown
            final weeks = _buildMonthWeeks(
              month: _selectedMonth,
              schedule: result.dailySchedule,
              completions: completions,
              now: now,
            );

            // Compute overall monthly totals
            final totalMonthlyScheduled = weeks.fold(0.0, (sum, w) => sum + w.scheduledHours);
            final totalMonthlyCompleted = weeks.fold(0.0, (sum, w) => sum + w.completedHours);
            final avgWeeklyHours = weeks.isNotEmpty ? (totalMonthlyScheduled / weeks.length) : 0.0;

            // Target distribution aggregated for the whole month
            final monthlyTargetHours = <String, double>{};
            for (final w in weeks) {
              w.targetHours.forEach((name, hrs) {
                monthlyTargetHours[name] = (monthlyTargetHours[name] ?? 0.0) + hrs;
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Month Navigation Header ──────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                                style: AppTypography.editorialHero(color: AppColors.textPrimary),
                              ),
                              if (!isCurrentMonth) ...[
                                const SizedBox(width: 8),
                                Tactile(
                                  onTap: _resetToCurrentMonth,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentWarmSubtle,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.accentWarm.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: AppTypography.overline(color: AppColors.accentWarm)
                                          .copyWith(fontSize: 9),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${weeks.length} WEEKS · MONTHLY OVERVIEW',
                            style: AppTypography.overline(color: AppColors.textTertiary),
                          ),
                        ],
                      ),

                      // Month Navigator Chevrons
                      Row(
                        children: [
                          Tactile(
                            onTap: _previousMonth,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tactile(
                            onTap: _nextMonth,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── 2. Scrollable Month Content ─────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                    children: [
                      // ── Summary KPI Bar ───────────────────
                      _buildMonthlyKpiBar(
                        totalScheduled: totalMonthlyScheduled,
                        totalCompleted: totalMonthlyCompleted,
                        avgWeekly: avgWeeklyHours,
                        weeksCount: weeks.length,
                      ),

                      const SizedBox(height: 16),

                      // ── Month Calendar Heatmap ────────────
                      _buildMonthCalendarGrid(
                        month: _selectedMonth,
                        schedule: result.dailySchedule,
                        completions: completions,
                        now: now,
                      ),

                      const SizedBox(height: 20),

                      // ── Weekly Breakdown Header ───────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'WEEKLY BREAKDOWN',
                            style: AppTypography.overline(color: AppColors.textTertiary),
                          ),
                          Text(
                            '${weeks.length} WEEKS SCHEDULED',
                            style: AppTypography.monoTime(
                              color: AppColors.textTertiary,
                            ).copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── Per-Week Breakdown Cards ──────────
                      ...weeks.map((week) => _buildWeekCard(week)),

                      const SizedBox(height: 20),

                      // ── Monthly Target Distribution ───────
                      _buildTargetDistributionCard(
                        targetHours: monthlyTargetHours,
                        totalHours: totalMonthlyScheduled,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// KPI metric card row showing total monthly hours, weekly average, and completed count.
  Widget _buildMonthlyKpiBar({
    required double totalScheduled,
    required double totalCompleted,
    required double avgWeekly,
    required int weeksCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL PLANNED',
                    style: AppTypography.overline(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalScheduled.toStringAsFixed(0),
                        style: AppTypography.editorialNumeral(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'hours',
                        style: AppTypography.caption(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.divider.withValues(alpha: 0.3),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEKLY AVG',
                    style: AppTypography.overline(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        avgWeekly.toStringAsFixed(1),
                        style: AppTypography.editorialNumeral(
                          color: AppColors.accentWarm,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'h / wk',
                        style: AppTypography.caption(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppColors.divider.withValues(alpha: 0.3),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PACING',
                    style: AppTypography.overline(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '100%',
                        style: AppTypography.editorialNumeral(
                          color: AppColors.accentSage,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'quota',
                        style: AppTypography.caption(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mini Month Calendar Heatmap Grid showing daily density.
  Widget _buildMonthCalendarGrid({
    required DateTime month,
    required Map<int, List<TimeBlock>> schedule,
    required List<TaskCompletion> completions,
    required DateTime now,
  }) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1=Mon ... 7=Sun

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekday Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final isWeekend = i >= 5;
              return SizedBox(
                width: 34,
                child: Center(
                  child: Text(
                    _weekdayShort[i],
                    style: AppTypography.overline(
                      color: isWeekend ? AppColors.textDisabled : AppColors.textTertiary,
                    ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Days Matrix
          Wrap(
            spacing: 0,
            runSpacing: 6,
            children: [
              // Empty leading slots for days before 1st of month
              ...List.generate(firstWeekday - 1, (i) {
                return const SizedBox(width: 44, height: 40);
              }),

              // Actual days of the month
              ...List.generate(daysInMonth, (index) {
                final dayNumber = index + 1;
                final date = DateTime(month.year, month.month, dayNumber);
                final weekday = date.weekday;
                final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                
                // Get scheduled hours for this day of week
                final dayBlocks = schedule[weekday] ?? [];
                final dayFloatingMinutes = dayBlocks
                    .where((b) => b.type == TimeBlockType.floating)
                    .fold(0, (sum, b) => sum + b.durationMinutes);
                final dayFloatingHours = dayFloatingMinutes / 60.0;

                // Intensity color level based on hours
                Color dotColor;
                if (dayFloatingHours >= 6.0) {
                  dotColor = AppColors.accentWarm;
                } else if (dayFloatingHours >= 3.5) {
                  dotColor = AppColors.accentSage;
                } else if (dayFloatingHours > 0) {
                  dotColor = AppColors.accentSteel;
                } else {
                  dotColor = Colors.transparent;
                }

                return SizedBox(
                  width: 44,
                  height: 40,
                  child: Tactile(
                    onTap: () {
                      // Navigate to daily view for this weekday
                      ref.read(selectedDayProvider.notifier).state = weekday;
                      ref.read(currentNavigationIndexProvider.notifier).state = 0;
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.surfaceElevated
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isToday
                              ? AppColors.accentWarm.withValues(alpha: 0.6)
                              : Colors.transparent,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: AppTypography.monoTime(
                              color: isToday
                                  ? AppColors.accentWarm
                                  : AppColors.textPrimary,
                            ).copyWith(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds an individual Week Breakdown Card.
  Widget _buildWeekCard(_MonthWeekData week) {
    final startFmt = '${_monthNames[week.startOfWeek.month - 1].substring(0, 3)} ${week.startOfWeek.day}';
    final endFmt = '${_monthNames[week.endOfWeek.month - 1].substring(0, 3)} ${week.endOfWeek.day}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tactile(
        onTap: () {
          // Select Monday of this week and switch to Daily tab
          ref.read(selectedDayProvider.notifier).state = week.startOfWeek.weekday;
          ref.read(currentNavigationIndexProvider.notifier).state = 0;
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: week.isCurrentWeek
                  ? AppColors.accentWarm.withValues(alpha: 0.35)
                  : AppColors.surfaceBorder,
              width: week.isCurrentWeek ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Week Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          'WEEK ${week.weekIndex}',
                          style: AppTypography.overline(
                            color: week.isCurrentWeek
                                ? AppColors.accentWarm
                                : AppColors.textSecondary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$startFmt – $endFmt',
                        style: AppTypography.cardTitle(color: AppColors.textPrimary)
                            .copyWith(fontSize: 14),
                      ),
                    ],
                  ),

                  // Status Badge
                  if (week.isCurrentWeek)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentWarmSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.accentWarm.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'CURRENT',
                        style: AppTypography.overline(color: AppColors.accentWarm)
                            .copyWith(fontSize: 9),
                      ),
                    )
                  else if (week.isPastWeek)
                    Text(
                      'PAST',
                      style: AppTypography.overline(color: AppColors.textDisabled)
                          .copyWith(fontSize: 9),
                    )
                  else
                    Text(
                      'UPCOMING',
                      style: AppTypography.overline(color: AppColors.textTertiary)
                          .copyWith(fontSize: 9),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Total Hours Number Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        week.scheduledHours.toStringAsFixed(1),
                        style: AppTypography.editorialNumeral(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'hours total',
                        style: AppTypography.caption(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  Text(
                    '${week.daysInMonth.length} active days in month',
                    style: AppTypography.monoTime(color: AppColors.textTertiary)
                        .copyWith(fontSize: 10),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Segmented Target Progress Bar
              if (week.scheduledHours > 0)
                _buildSegmentedTargetBar(week.targetHours, week.scheduledHours),

              const SizedBox(height: 12),

              // Target Hours Pill Badges
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: week.targetHours.entries.map((entry) {
                  final accent = AppColors.getTargetColor(entry.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          entry.key,
                          style: AppTypography.caption(color: AppColors.textSecondary)
                              .copyWith(fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.value.toStringAsFixed(1)}h',
                          style: AppTypography.monoTime(color: AppColors.textPrimary)
                              .copyWith(fontSize: 10.5, fontWeight: FontWeight.w600),
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
  }

  /// Multi-segment visual bar representing target proportions.
  Widget _buildSegmentedTargetBar(Map<String, double> targetHours, double totalHours) {
    if (totalHours <= 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: targetHours.entries.map((entry) {
            final flex = max(1, ((entry.value / totalHours) * 100).round());
            final accent = AppColors.getTargetColor(entry.key);

            return Expanded(
              flex: flex,
              child: Container(
                color: accent,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Monthly cumulative target distribution card.
  Widget _buildTargetDistributionCard({
    required Map<String, double> targetHours,
    required double totalHours,
  }) {
    return Container(
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
                'MONTHLY TARGET DISTRIBUTION',
                style: AppTypography.overline(color: AppColors.textTertiary),
              ),
              Text(
                '${totalHours.toStringAsFixed(0)}h TOTAL',
                style: AppTypography.monoTime(color: AppColors.textTertiary)
                    .copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...targetHours.entries.map((entry) {
            final targetName = entry.key;
            final hours = entry.value;
            final pct = totalHours > 0 ? (hours / totalHours) : 0.0;
            final accent = AppColors.getTargetColor(targetName);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            targetName,
                            style: AppTypography.cardTitle(color: AppColors.textPrimary)
                                .copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        '${hours.toStringAsFixed(1)}h (${(pct * 100).toStringAsFixed(0)}%)',
                        style: AppTypography.monoTime(color: AppColors.textSecondary)
                            .copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Calculates calendar weeks and hours spent for the selected month.
  List<_MonthWeekData> _buildMonthWeeks({
    required DateTime month,
    required Map<int, List<TimeBlock>> schedule,
    required List<TaskCompletion> completions,
    required DateTime now,
  }) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = <_MonthWeekData>[];

    var currentDay = 1;
    var weekIndex = 1;

    while (currentDay <= daysInMonth) {
      final date = DateTime(month.year, month.month, currentDay);
      final weekday = date.weekday; // 1=Mon ... 7=Sun

      // Start of this calendar week (Monday)
      final startOfWeek = DateTime(date.year, date.month, date.day - (weekday - 1));
      // End of this calendar week (Sunday)
      final endOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6);

      // Collect all days in this calendar week that fall within this month
      final daysInThisMonth = <DateTime>[];
      var checkDate = startOfWeek;
      while (!checkDate.isAfter(endOfWeek)) {
        if (checkDate.month == month.month && checkDate.year == month.year) {
          daysInThisMonth.add(checkDate);
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }

      // Calculate scheduled & completed hours for this week
      double weekScheduled = 0.0;
      double weekCompleted = 0.0;
      final targetHours = <String, double>{};

      for (final d in daysInThisMonth) {
        final dayBlocks = schedule[d.weekday] ?? [];
        for (final b in dayBlocks) {
          if (b.type == TimeBlockType.floating) {
            final hrs = b.durationMinutes / 60.0;
            weekScheduled += hrs;
            targetHours[b.label] = (targetHours[b.label] ?? 0.0) + hrs;
          }
        }
      }

      // Check if current week
      final isCurrentWeek = now.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          now.isBefore(endOfWeek.add(const Duration(days: 1)));
      final isPastWeek = endOfWeek.isBefore(now);

      weeks.add(_MonthWeekData(
        weekIndex: weekIndex,
        startOfWeek: startOfWeek,
        endOfWeek: endOfWeek,
        daysInMonth: daysInThisMonth,
        scheduledHours: weekScheduled,
        completedHours: weekCompleted,
        targetHours: targetHours,
        isCurrentWeek: isCurrentWeek,
        isPastWeek: isPastWeek,
      ));

      // Advance to next Monday
      currentDay += (8 - weekday);
      weekIndex++;
    }

    return weeks;
  }
}
