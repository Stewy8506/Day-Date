/// Dedicated Overrides & Deviations Manager — controls college cancellations,
/// re-balancing strategies, and custom blockout deviations.
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
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class DeviationsManagerPage extends ConsumerWidget {
  const DeviationsManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviationsAsync = ref.watch(rawDeviationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: deviationsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 2),
          ),
          error: (e, st) => Center(
            child: Text('Error: $e', style: AppTypography.body(color: AppColors.accentTerracotta)),
          ),
          data: (deviations) {
            final collegeDeviations = deviations
                .where((d) => d.type == DeviationType.collegeCancellation)
                .toList();
            final customDeviations = deviations
                .where((d) => d.type != DeviationType.collegeCancellation)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Top Header & Action ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCHEDULE CONTROLS',
                            style: AppTypography.overline(color: AppColors.textTertiary),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Overrides & Off-Days',
                            style: AppTypography.heroTitle(),
                          ),
                        ],
                      ),
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
                                'Add Override',
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

                // ── 2. Scrollable Body ───────────────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      // ── College Status Switcher Matrix ──────
                      Text(
                        'COLLEGE ATTENDANCE MATRIX',
                        style: AppTypography.overline(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          children: [
                            kMonday,
                            kTuesday,
                            kWednesday,
                            kThursday,
                            kFriday,
                          ].map((day) {
                            final dayName = kDayNames[day] ?? 'Day $day';
                            final cancellation = collegeDeviations.where((d) => d.dayOfWeek == day);
                            final isOff = cancellation.isNotEmpty;
                            final strategy = isOff ? cancellation.first.offDayStrategy : null;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                border: day != kFriday
                                    ? const Border(bottom: BorderSide(color: AppColors.divider))
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dayName,
                                        style: AppTypography.cardTitle(color: AppColors.textPrimary),
                                      ),
                                      if (isOff) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          strategy == OffDayStrategy.restAndLeisure
                                              ? 'Rest & Leisure'
                                              : 'Accelerate Week',
                                          style: AppTypography.caption(
                                            color: strategy == OffDayStrategy.restAndLeisure
                                                ? AppColors.accentSage
                                                : AppColors.accentWarm,
                                          ).copyWith(fontSize: 10.5),
                                        ),
                                      ],
                                    ],
                                  ),

                                  // Toggle Button
                                  Tactile(
                                    onTap: () {
                                      final now = DateTime.now();
                                      final daysUntil = (day - now.weekday) % 7;
                                      final targetDate = DateTime(now.year, now.month, now.day + daysUntil);

                                      ref.read(setCollegeStatusProvider)(
                                        targetDate,
                                        isAttending: isOff, // toggle
                                        strategy: OffDayStrategy.accelerateWeek,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isOff
                                            ? AppColors.accentTerracottaSubtle
                                            : AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isOff
                                              ? AppColors.accentTerracotta
                                              : AppColors.surfaceBorder,
                                        ),
                                      ),
                                      child: Text(
                                        isOff ? 'College Off' : 'Attending',
                                        style: AppTypography.overline(
                                          color: isOff ? AppColors.accentTerracotta : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Active Custom Deviations List ──────
                      Text(
                        'CUSTOM BLOCKOUTS & EXTENSIONS',
                        style: AppTypography.overline(color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 8),

                      if (customDeviations.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 24, color: AppColors.textTertiary),
                              const SizedBox(height: 8),
                              Text(
                                'No Custom Deviations',
                                style: AppTypography.cardTitle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Add appointments or outings to block time windows.',
                                style: AppTypography.caption(color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        )
                      else
                        ...customDeviations.map((dev) {
                          final dayName = kDayNames[dev.dayOfWeek] ?? 'Day ${dev.dayOfWeek}';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dev.label,
                                          style: AppTypography.cardTitle(color: AppColors.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$dayName • ${formatMinutes(dev.startMinutes)} – ${formatMinutes(dev.endMinutes)}',
                                          style: AppTypography.caption(color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Delete button
                                  Tactile(
                                    onTap: () {
                                      ref.read(removeDeviationProvider)(dev.id);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: AppColors.accentTerracotta,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
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
}
