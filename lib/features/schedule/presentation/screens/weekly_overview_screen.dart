/// Weekly overview screen — shows all 7 days with mini-block columns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/application/services/planner_service.dart';
import 'package:day_date/features/schedule/presentation/screens/daily_detail_screen.dart';
import 'package:day_date/features/schedule/presentation/widgets/day_column.dart';

class WeeklyOverviewScreen extends ConsumerWidget {
  const WeeklyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(weeklyScheduleProvider);
    final selectedDay = ref.watch(selectedDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day-Date'),
        centerTitle: true,
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (result) => Column(
          children: [
            // ── Weekly strip ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    return DayColumn(
                      dayOfWeek: day,
                      blocks: result.dailySchedule[day] ?? [],
                      isSelected: day == selectedDay,
                      onTap: () {
                        ref.read(selectedDayProvider.notifier).state = day;
                      },
                    );
                  }),
                ),
              ),
            ),

            // ── Allocation summary ───────────────────
            _AllocationSummary(result: result),

            // ── Selected day detail ──────────────────
            Expanded(
              child: DailyDetailScreen(
                dayOfWeek: selectedDay,
                blocks: result.dailySchedule[selectedDay] ?? [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationSummary extends StatelessWidget {
  final ScheduleResult result;

  const _AllocationSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.warnings.isEmpty && result.allocatedHours.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: result.warnings.isNotEmpty
            ? Colors.orange[50]
            : Colors.green[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hours summary row
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: result.allocatedHours.entries.map((e) {
              return _HourChip(
                label: _nameFromId(e.key, result),
                hours: e.value,
              );
            }).toList(),
          ),
          // Warnings
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...result.warnings.map((w) => Text(
                  '⚠ ${w.targetName}: ${w.shortfallHours.toStringAsFixed(1)}h short',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _nameFromId(String id, ScheduleResult result) {
    // Find the name from blocks
    for (final dayBlocks in result.dailySchedule.values) {
      for (final block in dayBlocks) {
        if (block.parentTargetId == id) return block.label;
      }
    }
    return id.substring(0, 6);
  }
}

class _HourChip extends StatelessWidget {
  final String label;
  final double hours;

  const _HourChip({required this.label, required this.hours});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        '$label: ${hours.toStringAsFixed(1)}h',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
