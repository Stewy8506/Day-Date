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
      body: Stack(
        children: [
          // Primary screen content
          IndexedStack(
            index: currentIndex,
            children: _pages,
          ),

          // Floating Detached Capsule Navigation Island
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.surfaceBorderLight,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
            ),
          ),
        ],
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
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 11,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppColors.surfaceBorderLight : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.badge(
                  color: AppColors.textPrimary,
                ).copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
