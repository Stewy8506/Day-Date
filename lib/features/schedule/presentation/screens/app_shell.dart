/// Main application shell providing the bottom navigation hub across
/// the 4 dedicated pages: Daily, Week, Targets, and Overrides.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/presentation/screens/daily_schedule_page.dart';
import 'package:day_date/features/schedule/presentation/screens/deviations_manager_page.dart';
import 'package:day_date/features/schedule/presentation/screens/targets_dashboard_page.dart';
import 'package:day_date/features/schedule/presentation/screens/weekly_matrix_page.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<Widget> _pages = [
    DailySchedulePage(),
    WeeklyMatrixPage(),
    TargetsDashboardPage(),
    DeviationsManagerPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentNavigationIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        padding: EdgeInsets.only(
          top: 6,
          bottom: MediaQuery.of(context).padding.bottom + 6,
          left: 12,
          right: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              ref: ref,
              index: 0,
              currentIndex: currentIndex,
              label: 'Daily',
              icon: Icons.calendar_today_rounded,
            ),
            _buildNavItem(
              ref: ref,
              index: 1,
              currentIndex: currentIndex,
              label: 'Week',
              icon: Icons.view_week_rounded,
            ),
            _buildNavItem(
              ref: ref,
              index: 2,
              currentIndex: currentIndex,
              label: 'Targets',
              icon: Icons.track_changes_rounded,
            ),
            _buildNavItem(
              ref: ref,
              index: 3,
              currentIndex: currentIndex,
              label: 'Overrides',
              icon: Icons.tune_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required WidgetRef ref,
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
  }) {
    final isSelected = index == currentIndex;

    return Tactile(
      onTap: () {
        ref.read(currentNavigationIndexProvider.notifier).state = index;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.surfaceBorderLight : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.caption(
                color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
              ).copyWith(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
