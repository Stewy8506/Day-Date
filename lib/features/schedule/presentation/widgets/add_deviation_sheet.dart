/// Bottom sheet for adding a schedule deviation or marking college off.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/theme/app_colors.dart';
import 'package:day_date/core/theme/app_typography.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/presentation/widgets/tactile_interactive.dart';

class AddDeviationSheet extends ConsumerStatefulWidget {
  const AddDeviationSheet({super.key});

  @override
  ConsumerState<AddDeviationSheet> createState() => _AddDeviationSheetState();
}

class _AddDeviationSheetState extends ConsumerState<AddDeviationSheet> {
  final _labelController = TextEditingController();
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  DeviationType _deviationType = DeviationType.blockout;
  OffDayStrategy _offDayStrategy = OffDayStrategy.accelerateWeek;

  bool get _isCollegeCancellation =>
      _deviationType == DeviationType.collegeCancellation;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: AppColors.surfaceBorder, width: 1),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OVERRIDE',
                      style: AppTypography.overline(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Schedule Deviation',
                      style: AppTypography.editorialTitle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Segmented Toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _buildSegment(
                    label: 'Blockout',
                    type: DeviationType.blockout,
                  ),
                  _buildSegment(
                    label: 'Extension',
                    type: DeviationType.extension,
                  ),
                  _buildSegment(
                    label: 'College Off',
                    type: DeviationType.collegeCancellation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Label (auto-filled for college cancellation)
            if (!_isCollegeCancellation) ...[
              TextField(
                controller: _labelController,
                style: AppTypography.body(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Label',
                  labelStyle: AppTypography.caption(color: AppColors.textSecondary),
                  hintText: 'e.g., Doctor Appointment, Outing',
                  hintStyle: AppTypography.caption(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Day picker
            DropdownButtonFormField<int>(
              initialValue: _selectedDay,
              dropdownColor: AppColors.surfaceElevated,
              style: AppTypography.body(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: _isCollegeCancellation ? 'College Day' : 'Day of Week',
                labelStyle: AppTypography.caption(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.textSecondary),
                ),
              ),
              items: kDayNames.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: AppTypography.body(color: AppColors.textPrimary)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedDay = v);
              },
            ),
            const SizedBox(height: 12),

            // Time pickers — only for blockout/extension
            if (!_isCollegeCancellation) ...[
              Row(
                children: [
                  Expanded(
                    child: _TimePicker(
                      label: 'Start Time',
                      time: _startTime,
                      onChanged: (t) => setState(() => _startTime = t),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimePicker(
                      label: 'End Time',
                      time: _endTime,
                      onChanged: (t) => setState(() => _endTime = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Off-day strategy — only for college cancellation
            if (_isCollegeCancellation) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RE-BALANCING STRATEGY',
                      style: AppTypography.overline(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<OffDayStrategy>(
                      groupValue: _offDayStrategy,
                      onChanged: (v) {
                        if (v != null) setState(() => _offDayStrategy = v);
                      },
                      child: Column(
                        children: [
                          RadioListTile<OffDayStrategy>(
                            title: Text(
                              'Accelerate Week',
                              style: AppTypography.bodyMedium(),
                            ),
                            subtitle: Text(
                              'Redistribute study goals into freed hours.',
                              style: AppTypography.caption(color: AppColors.textSecondary),
                            ),
                            value: OffDayStrategy.accelerateWeek,
                            activeColor: AppColors.textPrimary,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          const Divider(height: 8),
                          RadioListTile<OffDayStrategy>(
                            title: Text(
                              'Rest & Leisure',
                              style: AppTypography.bodyMedium(),
                            ),
                            subtitle: Text(
                              'Leave freed hours open as unallocated rest time.',
                              style: AppTypography.caption(color: AppColors.textSecondary),
                            ),
                            value: OffDayStrategy.restAndLeisure,
                            activeColor: AppColors.textPrimary,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tactile Submit Button
            Tactile(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isCollegeCancellation ? 'Apply College Off' : 'Add Deviation',
                  style: AppTypography.badge(color: AppColors.background).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment({
    required String label,
    required DeviationType type,
  }) {
    final isSelected = _deviationType == type;
    return Expanded(
      child: Tactile(
        onTap: () => setState(() => _deviationType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.caption(
              color: isSelected ? AppColors.textPrimary : AppColors.textTertiary,
            ).copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_isCollegeCancellation) {
      _submitCollegeCancellation();
    } else {
      _submitRegularDeviation();
    }
  }

  void _submitCollegeCancellation() {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final daysUntilTarget = (_selectedDay - currentWeekday) % 7;
    final targetDate = DateTime(
      now.year,
      now.month,
      now.day + daysUntilTarget,
    );

    final deviation = ScheduleDeviation(
      id: const Uuid().v4(),
      label: 'College Off',
      type: DeviationType.collegeCancellation,
      dayOfWeek: _selectedDay,
      startMinutes: 0,
      endMinutes: 0,
      offDayStrategy: _offDayStrategy,
      date: targetDate,
    );

    ref.read(addDeviationProvider)(deviation);
    Navigator.of(context).pop();
  }

  void _submitRegularDeviation() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a label')),
      );
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final deviation = ScheduleDeviation(
      id: const Uuid().v4(),
      label: label,
      type: _deviationType,
      dayOfWeek: _selectedDay,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );

    ref.read(addDeviationProvider)(deviation);
    Navigator.of(context).pop();
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Tactile(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.overline(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 3),
            Text(
              time.format(context),
              style: AppTypography.monoNumber(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
