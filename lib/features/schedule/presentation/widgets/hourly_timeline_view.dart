/// Unique Hourly Timeline View — a continuous proportional day calendar
/// with precise hourly grid lines, visual free-time slots, interactive completion checkboxes,
/// and quick-action sheets for extending and skipping tasks.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/task_completion.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/presentation/widgets/block_action_sheet.dart';

class HourlyTimelineView extends ConsumerStatefulWidget {
  final int dayOfWeek;
  final List<TimeBlock> blocks;

  const HourlyTimelineView({
    super.key,
    required this.dayOfWeek,
    required this.blocks,
  });

  @override
  ConsumerState<HourlyTimelineView> createState() => _HourlyTimelineViewState();
}

class _HourlyTimelineViewState extends ConsumerState<HourlyTimelineView> {
  late final ScrollController _scrollController;

  // Timeline configuration
  int get _startHour => (widget.dayOfWeek == kSaturday || widget.dayOfWeek == kSunday) ? 10 : 7;
  static const int kTimelineEndHour = 24; // 12:00 AM
  static const double kHourHeight = 68.0; // dp per hour
  static const double kMinutesPerHour = 60.0;
  static const double kPixelsPerMinute = kHourHeight / kMinutesPerHour;
  static const double kTimeColumnWidth = 54.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Auto-scroll to first block or morning start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToRelevantTime();
    });
  }

  @override
  void didUpdateWidget(covariant HourlyTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayOfWeek != widget.dayOfWeek) {
      _scrollToRelevantTime();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToRelevantTime() {
    if (!_scrollController.hasClients) return;

    final startHour = _startHour;
    final firstBlockStart = widget.blocks.isNotEmpty
        ? widget.blocks.map((b) => b.startMinutes).reduce(min)
        : (startHour * 60);

    final offsetMinutes = max(0, firstBlockStart - (startHour * 60) - 15);
    final targetOffset = offsetMinutes * kPixelsPerMinute;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final completionsAsync = ref.watch(rawTaskCompletionsProvider);
    final completions = completionsAsync.value ?? [];

    final now = DateTime.now();
    final isToday = now.weekday == widget.dayOfWeek;
    final nowMinutes = now.hour * 60 + now.minute;

    final startHour = _startHour;
    final totalHours = kTimelineEndHour - startHour;
    final totalHeight = totalHours * kHourHeight;

    // Compute free time gaps between sorted scheduled blocks
    final sortedBlocks = List<TimeBlock>.from(widget.blocks)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final freeGaps = _computeFreeGaps(sortedBlocks, startHour);

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: SizedBox(
        height: totalHeight + 40,
        child: Stack(
          children: [
            // ── 1. Hourly Grid Lines & Left Hour Labels ─
            ...List.generate(totalHours + 1, (i) {
              final hour = startHour + i;
              final top = i * kHourHeight;
              final isMiddayOrMidnight = hour == 12 || hour == 24;

              return Positioned(
                top: top,
                left: 0,
                right: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hour label
                    SizedBox(
                      width: kTimeColumnWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, top: 0),
                        child: Text(
                          _formatHour(hour),
                          style: AppTypography.monoTime(
                            color: isMiddayOrMidnight
                                ? AppColors.textSecondary
                                : AppColors.textTertiary.withValues(alpha: 0.7),
                          ).copyWith(
                            fontSize: 10,
                            fontWeight: isMiddayOrMidnight ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    // Grid divider line
                    Expanded(
                      child: Container(
                        height: 1,
                        color: AppColors.divider.withValues(alpha: isMiddayOrMidnight ? 0.35 : 0.18),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // ── 2. Subtle Half-Hour Dashed Guidelines ───
            ...List.generate(totalHours, (i) {
              final top = (i * kHourHeight) + (kHourHeight / 2);
              return Positioned(
                top: top,
                left: kTimeColumnWidth + 8,
                right: 16,
                child: Container(
                  height: 1,
                  color: AppColors.divider.withValues(alpha: 0.08),
                ),
              );
            }),

            // ── 3. Visual Free Time Gaps ────────────────
            ...freeGaps.map((gap) {
              final top = (gap.start - (startHour * 60)) * kPixelsPerMinute;
              final height = gap.duration * kPixelsPerMinute - 4;
              if (height < 18) return const SizedBox.shrink();

              final isLunchWindow = gap.start >= 840 && gap.end <= 930;

              return Positioned(
                top: top + 2,
                left: kTimeColumnWidth + 8,
                right: 16,
                height: max(18, height),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLunchWindow
                        ? AppColors.surfaceElevated.withValues(alpha: 0.35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLunchWindow
                          ? AppColors.accentWarm.withValues(alpha: 0.15)
                          : AppColors.divider.withValues(alpha: 0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLunchWindow ? Icons.restaurant_outlined : Icons.schedule_outlined,
                        size: 11,
                        color: isLunchWindow ? AppColors.accentWarm : AppColors.textDisabled,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLunchWindow
                            ? 'Weekend Lunch & Rest (${formatDuration(gap.duration)})'
                            : 'Free Window · ${formatDuration(gap.duration)}',
                        style: AppTypography.caption(
                          color: isLunchWindow ? AppColors.accentWarm : AppColors.textDisabled,
                        ).copyWith(fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ── 4. Proportional Event Blocks ────────────
            ...sortedBlocks.map((block) {
              final top = (block.startMinutes - (startHour * 60)) * kPixelsPerMinute;
              final height = max(48.0, (block.durationMinutes * kPixelsPerMinute) - 4);

              // Find completion record if any
              final completion = completions.cast<TaskCompletion?>().firstWhere(
                    (c) => c != null &&
                        (c.blockId == block.id ||
                            (block.parentTargetId != null &&
                                c.targetId == block.parentTargetId &&
                                c.dayOfWeek == widget.dayOfWeek)) &&
                        c.dayOfWeek == widget.dayOfWeek,
                    orElse: () => null,
                  );

              final isCompleted = completion?.isCompleted ?? false;
              final isFocus = block.type == TimeBlockType.floating;
              final isGym = block.label.toLowerCase().contains('gym');

              return Positioned(
                top: top + 2,
                left: kTimeColumnWidth + 8,
                right: 16,
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.surfaceElevated.withValues(alpha: 0.6)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.accentSage.withValues(alpha: 0.4)
                          : isFocus
                              ? AppColors.accentWarm.withValues(alpha: 0.25)
                              : AppColors.surfaceBorder,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left Category Accent Node
                          Container(
                            width: 3.5,
                            height: max(20, height - 16),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.accentSage
                                  : isFocus
                                      ? AppColors.accentWarm
                                      : isGym
                                          ? AppColors.accentSage
                                          : AppColors.accentTerracotta,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Main Content Area (Tapping opens action sheet)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                BlockActionSheet.show(
                                  context,
                                  block: block,
                                  dayOfWeek: widget.dayOfWeek,
                                  completion: completion,
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Category Eyebrow Tag
                                  Row(
                                    children: [
                                      Text(
                                        isFocus
                                            ? 'FOCUS'
                                            : isGym
                                                ? 'TRAINING'
                                                : 'ANCHOR',
                                        style: AppTypography.overline(
                                          color: isCompleted
                                              ? AppColors.accentSage
                                              : isFocus
                                                  ? AppColors.accentWarm
                                                  : AppColors.textTertiary,
                                        ).copyWith(fontSize: 8.0, height: 1.1),
                                      ),
                                      if (isCompleted) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentSageSubtle,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            'DONE',
                                            style: AppTypography.overline(color: AppColors.accentSage)
                                                .copyWith(fontSize: 7.5, height: 1.1),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 1),

                                  // Block Title
                                  Text(
                                    block.label,
                                    style: AppTypography.cardTitle(
                                      color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                                    ).copyWith(
                                      fontSize: height < 60 ? 12.5 : 13.0,
                                      height: 1.15,
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      decorationColor: AppColors.accentSage,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),

                                  // Time and Duration
                                  Text(
                                    '${formatMinutes(block.startMinutes)} – ${formatMinutes(block.endMinutes)} (${formatDuration(block.durationMinutes)})',
                                    style: AppTypography.monoTime(
                                      color: isCompleted ? AppColors.textDisabled : AppColors.textSecondary,
                                    ).copyWith(fontSize: 9.5, height: 1.1),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Dedicated Interactive Done Toggle Checkbox
                          if (isFocus)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                ref.read(toggleTaskCompletionProvider)(
                                  block: block,
                                  dayOfWeek: widget.dayOfWeek,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Icon(
                                  isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 22,
                                  color: isCompleted ? AppColors.accentSage : AppColors.textTertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // ── 5. Live "Now" Time Indicator Line ───────
            if (isToday && nowMinutes >= (startHour * 60) && nowMinutes <= (kTimelineEndHour * 60)) ...[
              Positioned(
                top: (nowMinutes - (startHour * 60)) * kPixelsPerMinute,
                left: kTimeColumnWidth - 6,
                right: 0,
                child: Row(
                  children: [
                    // Glowing indicator dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.accentWarm,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentWarm,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    // Horizontal indicator line
                    Expanded(
                      child: Container(
                        height: 1.5,
                        color: AppColors.accentWarm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0 || hour == 24) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }

  List<({int start, int end, int duration})> _computeFreeGaps(List<TimeBlock> sortedBlocks, int startHour) {
    final gaps = <({int start, int end, int duration})>[];
    int currentPointer = startHour * 60;

    for (final block in sortedBlocks) {
      if (block.startMinutes > currentPointer) {
        final gapDuration = block.startMinutes - currentPointer;
        if (gapDuration >= 20) {
          gaps.add((start: currentPointer, end: block.startMinutes, duration: gapDuration));
        }
      }
      currentPointer = max(currentPointer, block.endMinutes);
    }

    if (currentPointer < (kTimelineEndHour * 60)) {
      final gapDuration = (kTimelineEndHour * 60) - currentPointer;
      if (gapDuration >= 20) {
        gaps.add((start: currentPointer, end: kTimelineEndHour * 60, duration: gapDuration));
      }
    }

    return gaps;
  }
}
