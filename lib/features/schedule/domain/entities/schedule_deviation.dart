/// A user-reported deviation that blocks time or extends a fixed block.
library;

import 'package:equatable/equatable.dart';

/// The type of schedule deviation.
enum DeviationType {
  /// Blocks out a time range (e.g., outing, appointment).
  blockout,

  /// Extends an existing fixed block (e.g., college extended by 2 hours).
  extension,
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

  const ScheduleDeviation({
    required this.id,
    required this.label,
    required this.type,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.extendsBlockId,
    this.extensionMinutes,
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
      ];

  @override
  String toString() =>
      'ScheduleDeviation($label, day=$dayOfWeek, $startMinutes-$endMinutes, $type)';
}
