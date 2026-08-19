/// Bottom sheet modal for interacting with a scheduled time block:
/// marking Done / Not Done, extending duration, skipping anchors (Gym, College),
/// and logging overtime.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/entities/task_completion.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class BlockActionSheet extends ConsumerStatefulWidget {
  final TimeBlock block;
  final int dayOfWeek;
  final TaskCompletion? completion;

  const BlockActionSheet({
    super.key,
    required this.block,
    required this.dayOfWeek,
    this.completion,
  });

  static Future<void> show(
    BuildContext context, {
    required TimeBlock block,
    required int dayOfWeek,
    TaskCompletion? completion,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlockActionSheet(
        block: block,
        dayOfWeek: dayOfWeek,
        completion: completion,
      ),
    );
  }

  @override
  ConsumerState<BlockActionSheet> createState() => _BlockActionSheetState();
}

class _BlockActionSheetState extends ConsumerState<BlockActionSheet> {
  late bool _isCompleted;
  late int _actualMinutes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.completion?.isCompleted ?? false;
    _actualMinutes =
        widget.completion?.actualMinutes ?? widget.block.durationMinutes;
  }

  bool get _isFocus => widget.block.type == TimeBlockType.floating;
  bool get _isFixed => widget.block.type == TimeBlockType.fixed;
  bool get _isGym => widget.block.label.toLowerCase().contains('gym');

  void _adjustActualMinutes(int delta) {
    setState(() {
      _actualMinutes = (_actualMinutes + delta).clamp(15, 600);
      _isCompleted = true; // Automatically mark done if adjusting actual time
    });
  }

  Future<void> _toggleCompletion() async {
    setState(() => _isSaving = true);
    final newStatus = !_isCompleted;
    await ref.read(toggleTaskCompletionProvider)(
      block: widget.block,
      dayOfWeek: widget.dayOfWeek,
      forceStatus: newStatus,
      actualMinutes: _actualMinutes,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveActualTime() async {
    setState(() => _isSaving = true);
    await ref.read(toggleTaskCompletionProvider)(
      block: widget.block,
      dayOfWeek: widget.dayOfWeek,
      forceStatus: true,
      actualMinutes: _actualMinutes,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _extendBlock(int targetEndMinutes) async {
    setState(() => _isSaving = true);

    final delta = targetEndMinutes - widget.block.endMinutes;
    if (delta > 0) {
      // Add extension deviation
      final deviation = ScheduleDeviation(
        id: const Uuid().v4(),
        label: '${widget.block.label} Extension',
        dayOfWeek: widget.dayOfWeek,
        startMinutes: widget.block.startMinutes,
        endMinutes: targetEndMinutes,
        type: DeviationType.extension,
        extendsBlockId: widget.block.id,
        extensionMinutes: delta,
      );
      await ref.read(addDeviationProvider)(deviation);

      // Also update completion record with extended duration
      await ref.read(toggleTaskCompletionProvider)(
        block: widget.block,
        dayOfWeek: widget.dayOfWeek,
        forceStatus: true,
        actualMinutes: widget.block.durationMinutes + delta,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _skipFixedBlock() async {
    setState(() => _isSaving = true);

    // Create a blockout deviation that frees up this time window
    // Or if college, use college cancellation
    if (widget.block.label.toLowerCase().contains('college')) {
      final now = DateTime.now();
      // compute target date for this dayOfWeek
      final daysAhead = (widget.dayOfWeek - now.weekday) % 7;
      final targetDate = now.add(Duration(days: daysAhead));
      await ref.read(setCollegeStatusProvider)(
        targetDate,
        isAttending: false,
        strategy: OffDayStrategy.accelerateWeek,
      );
    } else {
      // For Gym or other fixed blocks: blockout deviation
      final deviation = ScheduleDeviation(
        id: const Uuid().v4(),
        label: 'Skip ${widget.block.label}',
        dayOfWeek: widget.dayOfWeek,
        startMinutes: widget.block.startMinutes,
        endMinutes: widget.block.endMinutes,
        type: DeviationType.blockout,
      );
      await ref.read(addDeviationProvider)(deviation);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag Handle ─────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header Card ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3.5,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isFocus
                          ? AppColors.accentWarm
                          : _isGym
                          ? AppColors.accentSage
                          : AppColors.accentTerracotta,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isFocus
                                  ? 'FOCUS TASK'
                                  : _isGym
                                  ? 'TRAINING ANCHOR'
                                  : 'FIXED ANCHOR',
                              style: AppTypography.overline(
                                color: _isFocus
                                    ? AppColors.accentWarm
                                    : AppColors.textTertiary,
                              ),
                            ),
                            if (_isCompleted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentSageSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'COMPLETED',
                                  style: AppTypography.overline(
                                    color: AppColors.accentSage,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          block.label,
                          style: AppTypography.sectionTitle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${formatMinutes(block.startMinutes)} — ${formatMinutes(block.endMinutes)} · ${formatDuration(block.durationMinutes)}',
                          style: AppTypography.monoTime(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 16),

              // ── 1. Completion & Actual Time Tracker ─
              Text(
                'TRACK COMPLETION & TIME',
                style: AppTypography.overline(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // Toggle Done Button
                  Expanded(
                    child: Tactile(
                      onTap: _isSaving ? null : _toggleCompletion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isCompleted
                              ? AppColors.accentSageSubtle
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isCompleted
                                ? AppColors.accentSage
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: _isCompleted
                                  ? AppColors.accentSage
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isCompleted ? 'Marked Done' : 'Mark as Done',
                              style: AppTypography.cardTitle(
                                color: _isCompleted
                                    ? AppColors.accentSage
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Log Actual Duration Stepper
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LOGGED TIME',
                          style: AppTypography.caption(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          formatDuration(_actualMinutes),
                          style: AppTypography.monoNumber(
                            fontSize: 14,
                            color: _actualMinutes > block.durationMinutes
                                ? AppColors.accentWarm
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTimeChip('-30m', () => _adjustActualMinutes(-30)),
                        const SizedBox(width: 6),
                        _buildTimeChip('-15m', () => _adjustActualMinutes(-15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Center(
                            child: Text(
                              _actualMinutes > block.durationMinutes
                                  ? '+${formatDuration(_actualMinutes - block.durationMinutes)} OT'
                                  : 'Scheduled',
                              style: AppTypography.caption(
                                color: _actualMinutes > block.durationMinutes
                                    ? AppColors.accentWarm
                                    : AppColors.textDisabled,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTimeChip('+15m', () => _adjustActualMinutes(15)),
                        const SizedBox(width: 6),
                        _buildTimeChip('+30m', () => _adjustActualMinutes(30)),
                        const SizedBox(width: 6),
                        _buildTimeChip('+1h', () => _adjustActualMinutes(60)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 2. Extend Task / Overtime Action ─────
              if (_isFocus) ...[
                Text(
                  'EXTEND SESSION ON SCHEDULE',
                  style: AppTypography.overline(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildExtendButton(
                        label: '+30m',
                        targetEnd: block.endMinutes + 30,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExtendButton(
                        label: '+1h',
                        targetEnd: block.endMinutes + 60,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildExtendButton(
                        label: '+2h',
                        targetEnd: block.endMinutes + 120,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (block.endMinutes <
                        1170) // If before Gym (7:30 PM = 1170)
                      Expanded(
                        child: _buildExtendButton(
                          label: 'Extend to 7:30 PM (Pre-Gym)',
                          targetEnd: 1170,
                        ),
                      ),
                    if (block.endMinutes < 1290 &&
                        block.endMinutes >= 1170) // If Gym slot
                      Expanded(
                        child: _buildExtendButton(
                          label: 'Extend to 9:30 PM',
                          targetEnd: 1290,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // ── 3. Skip Fixed Anchor Action ──────────
              if (_isFixed) ...[
                Text(
                  'SCHEDULE OVERRIDE',
                  style: AppTypography.overline(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),
                Tactile(
                  onTap: _isSaving ? null : _skipFixedBlock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.event_busy_outlined,
                          size: 16,
                          color: AppColors.accentTerracotta,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Skip ${block.label} Today',
                          style: AppTypography.cardTitle(
                            color: AppColors.accentTerracotta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Save / Close Button ──────────────────
              Tactile(
                onTap: _isSaving ? null : _saveActualTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.accentWarm,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.background,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Done',
                            style: AppTypography.cardTitle(
                              color: AppColors.background,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, VoidCallback onTap) {
    return Tactile(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: AppTypography.monoNumber(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildExtendButton({required String label, required int targetEnd}) {
    return Tactile(
      onTap: _isSaving ? null : () => _extendBlock(targetEnd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.caption(
              color: AppColors.accentWarm,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
