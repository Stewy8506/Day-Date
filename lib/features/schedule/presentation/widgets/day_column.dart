/// A compact column showing one day's schedule in the weekly overview.
library;

import 'package:flutter/material.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';

class DayColumn extends StatelessWidget {
  final int dayOfWeek;
  final List<TimeBlock> blocks;
  final bool isSelected;
  final VoidCallback onTap;

  const DayColumn({
    super.key,
    required this.dayOfWeek,
    required this.blocks,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayName = kDayNames[dayOfWeek]!;
    final shortName = dayName.substring(0, 3);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Day header
            Text(
              shortName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            // Mini-blocks
            ...blocks.take(6).map((b) => _MiniBlock(block: b)),
            if (blocks.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${blocks.length - 6}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniBlock extends StatelessWidget {
  final TimeBlock block;

  const _MiniBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 14,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Text(
        _shortLabel,
        style: const TextStyle(
          fontSize: 7,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.clip,
      ),
    );
  }

  String get _shortLabel {
    if (block.label.length <= 5) return block.label;
    return '${block.label.substring(0, 4)}…';
  }

  Color get _color {
    switch (block.type) {
      case TimeBlockType.fixed:
        return Colors.blueGrey;
      case TimeBlockType.deviation:
        return Colors.red;
      case TimeBlockType.floating:
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
}
