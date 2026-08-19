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
  int get _startHour => (widget.dayOfWeek == kSaturday || widget.dayOfWeek == kSunday)
      ? (kWeekendStartMinutes ~/ 60)
      : (kWeekdayStartMinutes ~/ 60);
  static const int kTimelineEndHour = 24; // 12:00 AM
  static const double kHourHeight = 68.0; // dp per hour
  static const double kMinutesPerHour = 60.0;
  static const double kPixelsPerMinute = kHourHeight / kMinutesPerHour;
  static const double kTimeColumnWidth = 54.0;
  static const double kMinFreeGapMinutes = 30.0; // Only show free gaps > 30m

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

  /// Compute free time gaps between scheduled blocks.
  List<({int start, int end})> _computeFreeGaps(List<TimeBlock> sortedBlocks) {
    final gaps = <({int start, int end})>[];
    final dayStart = _startHour * 60;
    final dayEnd = kTimelineEndHour * 60;

    int cursor = dayStart;
    for (final block in sortedBlocks) {
      if (block.startMinutes > cursor) {
        final gapDuration = block.startMinutes - cursor;
        if (gapDuration >= kMinFreeGapMinutes) {
          gaps.add((start: cursor, end: block.startMinutes));
        }
      }
      cursor = max(cursor, block.endMinutes);
    }
    // Trailing gap after last block
    if (cursor < dayEnd) {
      final gapDuration = dayEnd - cursor;
      if (gapDuration >= kMinFreeGapMinutes) {
        gaps.add((start: cursor, end: dayEnd));
      }
    }
    return gaps;
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
    
    final freeGaps = _computeFreeGaps(sortedBlocks);

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      child: SizedBox(
        height: totalHeight + 96,
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

            // ── 2.5. Free Time Gap Placeholders ─────────
            ...freeGaps.map((gap) {
              final top = (gap.start - (startHour * 60)) * kPixelsPerMinute;
              final height = (gap.end - gap.start) * kPixelsPerMinute;
              final gapMinutes = gap.end - gap.start;

              return Positioned(
                top: top + 2,
                left: kTimeColumnWidth + 8,
                right: 16,
                height: max(36.0, height - 4),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 11,
                          color: AppColors.textDisabled.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Free · ${formatDuration(gapMinutes)}',
                          style: AppTypography.monoTime(
                            color: AppColors.textDisabled.withValues(alpha: 0.7),
                          ).copyWith(fontSize: 10, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            // ── 3. Proportional Event Blocks ────────────
            ...sortedBlocks.map((block) {
              final top = (block.startMinutes - (startHour * 60)) * kPixelsPerMinute;
              final rawHeight = (block.durationMinutes * kPixelsPerMinute) - 4;
              final height = max(42.0, rawHeight);
              final isCompact = rawHeight < 54;

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
              
              // Per-target accent color
              final targetAccent = AppColors.getTargetColor(block.label);
              
              // Temporal state: past / current / future
              final isPast = isToday && block.endMinutes <= nowMinutes;
              final isCurrent = isToday && block.startMinutes <= nowMinutes && block.endMinutes > nowMinutes;
              final temporalOpacity = isPast ? 0.5 : 1.0;

              // Background & border colors based on target accent
              final bgColor = isCompleted
                  ? AppColors.surfaceElevated.withValues(alpha: 0.4)
                  : isCurrent
                      ? targetAccent.withValues(alpha: 0.08)
                      : (isFocus
                          ? targetAccent.withValues(alpha: 0.04)
                          : (isGym ? const Color(0xFF131714) : AppColors.surface));
              
              final borderColor = isCompleted
                  ? AppColors.accentSage.withValues(alpha: 0.25)
                  : isCurrent
                      ? targetAccent.withValues(alpha: 0.4)
                      : (isFocus
                          ? targetAccent.withValues(alpha: 0.15)
                          : (isGym
                              ? const Color(0xFF1E2920)
                              : AppColors.surfaceBorder));

              return Positioned(
                top: top + 1.5,
                left: kTimeColumnWidth + 8,
                right: 16,
                height: height,
                child: Opacity(
                  opacity: temporalOpacity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor,
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: targetAccent.withValues(alpha: 0.15),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          // Left accent bar
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.accentSage
                                  : targetAccent,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                            ),
                          ),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: isCompact ? 4 : 8,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
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
                                      child: isCompact
                                          ? _buildCompactContent(block, isCompleted, targetAccent, isGym)
                                          : _buildFullContent(block, isCompleted, targetAccent, isGym),
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
                                        padding: const EdgeInsets.only(left: 6, top: 0),
                                        child: Icon(
                                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          size: 18,
                                          color: isCompleted ? AppColors.accentSage : AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                                ],
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

  /// Full content layout for blocks with enough height (≥ 54px).
  Widget _buildFullContent(TimeBlock block, bool isCompleted, Color accent, bool isGym) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Block Title
        Text(
          block.label,
          style: AppTypography.cardTitle(
            color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
          ).copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.15,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.accentSage,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Status Dot + Time & Duration
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4.5,
              height: 4.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppColors.accentSage : accent,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${formatMinutes(block.startMinutes)} – ${formatMinutes(block.endMinutes)} · ${formatDuration(block.durationMinutes)}',
                style: AppTypography.monoTime(
                  color: isCompleted ? AppColors.textDisabled : AppColors.textSecondary,
                ).copyWith(fontSize: 10.5, height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Compact single-line layout for short blocks (< 54px height).
  /// Prevents overflow by combining title and time into one row.
  Widget _buildCompactContent(TimeBlock block, bool isCompleted, Color accent, bool isGym) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? AppColors.accentSage : accent,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${block.label} · ${formatDuration(block.durationMinutes)}',
            style: AppTypography.cardTitle(
              color: isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
            ).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.1,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.accentSage,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    if (hour == 0 || hour == 24) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour > 12) return '${hour - 12} PM';
    return '$hour AM';
  }
}
