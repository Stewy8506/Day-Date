/// Daily detail screen — timeline of all blocks for a single day.
library;

import 'package:flutter/material.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/presentation/widgets/add_deviation_sheet.dart';
import 'package:day_date/features/schedule/presentation/widgets/time_block_card.dart';

class DailyDetailScreen extends StatelessWidget {
  final int dayOfWeek;
  final List<TimeBlock> blocks;

  const DailyDetailScreen({
    super.key,
    required this.dayOfWeek,
    required this.blocks,
  });

  @override
  Widget build(BuildContext context) {
    final dayName = kDayNames[dayOfWeek] ?? 'Day $dayOfWeek';

    return Column(
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                dayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${blocks.length} blocks',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),

        // Block list
        Expanded(
          child: blocks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text(
                        'No blocks scheduled',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 80),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) =>
                      TimeBlockCard(block: blocks[index]),
                ),
        ),

        // FAB area
        Padding(
          padding: const EdgeInsets.only(bottom: 16, right: 16),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => const AddDeviationSheet(),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Deviation'),
            ),
          ),
        ),
      ],
    );
  }
}
