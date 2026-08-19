/// A card widget representing a single time block in the schedule.
library;

import 'package:flutter/material.dart';

import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';

class TimeBlockCard extends StatelessWidget {
  final TimeBlock block;

  const TimeBlockCard({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: _backgroundColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: block.type == TimeBlockType.deviation
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Color indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Label + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMinutes(block.startMinutes)} – ${formatMinutes(block.endMinutes)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Duration badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatDuration(block.durationMinutes),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (block.type) {
      case TimeBlockType.fixed:
        return Colors.grey[100]!;
      case TimeBlockType.floating:
        return _targetColor.withValues(alpha: 0.08);
      case TimeBlockType.deviation:
        return Colors.red[50]!;
    }
  }

  Color get _accentColor {
    switch (block.type) {
      case TimeBlockType.fixed:
        return Colors.blueGrey;
      case TimeBlockType.floating:
        return _targetColor;
      case TimeBlockType.deviation:
        return Colors.red;
    }
  }

  Color get _targetColor {
    switch (block.label) {
      case 'SWE Roadmap':
        return Colors.indigo;
      case 'CAT Prep':
        return Colors.teal;
      case 'Freelancing':
        return Colors.deepPurple;
      case 'ECE Upkeep':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
