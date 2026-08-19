/// A user-reported deviation that blocks time, extends a fixed block,
/// or cancels college for a specific date.
library;

import 'package:equatable/equatable.dart';

/// The type of schedule deviation.
enum DeviationType {
  /// Blocks out a time range (e.g., outing, appointment).
  blockout,

  /// Extends an existing fixed block (e.g., college extended by 2 hours).
  extension,

  /// Cancels college (and commute) for a specific date.
  /// Combined with [OffDayStrategy] to control re-balancing.
  collegeCancellation,
}

/// Strategy for re-balancing the schedule when college is cancelled.
enum OffDayStrategy {
  /// Freed college/commute hours become available for floating targets.
  /// The bounded interleaved strategy fills them, potentially fulfilling
  /// weekly quotas earlier and freeing later days.
  accelerateWeek,

  /// Freed hours are left as unallocated "Free Time".
  /// The rest of the week's schedule remains unchanged.
  restAndLeisure,
}

class ScheduleDeviation extends Equatable {
  /// Unique identifier.
  final String id;

  /// Human-readable label (e.g., "Outing", "College extended").
  final String label;

  /// The type of deviation.
  final DeviationType type;

  /// Day of the week (1=Monday .. 7=Sunday).
  final int dayOfWeek;

  /// Start time as minutes since midnight.
  final int startMinutes;

  /// End time as minutes since midnight.
  final int endMinutes;

  /// For extensions: the ID of the fixed block being extended.
  final String? extendsBlockId;

  /// For extensions: how many extra minutes to add.
  final int? extensionMinutes;

  /// For college cancellations: the re-balancing strategy.
  final OffDayStrategy? offDayStrategy;

  /// The specific calendar date this deviation applies to.
  /// Used for date-aware deviations (e.g., college cancelled on 2026-08-20).
  final DateTime? date;

  const ScheduleDeviation({
    required this.id,
    required this.label,
    required this.type,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.extendsBlockId,
    this.extensionMinutes,
    this.offDayStrategy,
    this.date,
  });

  /// Duration in minutes.
  int get durationMinutes => endMinutes - startMinutes;

  @override
  List<Object?> get props => [
        id,
        label,
        type,
        dayOfWeek,
        startMinutes,
        endMinutes,
        extendsBlockId,
        extensionMinutes,
        offDayStrategy,
        date,
      ];

  @override
  String toString() =>
      'ScheduleDeviation($label, day=$dayOfWeek, $startMinutes-$endMinutes, $type'
      '${date != null ? ', date=$date' : ''}'
      '${offDayStrategy != null ? ', strategy=$offDayStrategy' : ''})';
}
