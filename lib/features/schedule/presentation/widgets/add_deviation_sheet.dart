/// Bottom sheet for adding a schedule deviation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/application/providers/schedule_providers.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';

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

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Add Deviation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Label
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g., Outing, Doctor appointment',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Day picker
            DropdownButtonFormField<int>(
              initialValue: _selectedDay,
              decoration: const InputDecoration(
                labelText: 'Day',
                border: OutlineInputBorder(),
              ),
              items: kDayNames.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedDay = v);
              },
            ),
            const SizedBox(height: 16),

            // Time pickers
            Row(
              children: [
                Expanded(
                  child: _TimePicker(
                    label: 'Start',
                    time: _startTime,
                    onChanged: (t) => setState(() => _startTime = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePicker(
                    label: 'End',
                    time: _endTime,
                    onChanged: (t) => setState(() => _endTime = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type toggle
            SegmentedButton<DeviationType>(
              segments: const [
                ButtonSegment(
                  value: DeviationType.blockout,
                  label: Text('Blockout'),
                  icon: Icon(Icons.block),
                ),
                ButtonSegment(
                  value: DeviationType.extension,
                  label: Text('Extension'),
                  icon: Icon(Icons.add_circle_outline),
                ),
              ],
              selected: {_deviationType},
              onSelectionChanged: (s) =>
                  setState(() => _deviationType = s.first),
            ),
            const SizedBox(height: 24),

            // Submit
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Add Deviation'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
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
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(time.format(context)),
      ),
    );
  }
}
