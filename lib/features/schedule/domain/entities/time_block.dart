/// Represents a scheduled block of time on a specific day.
///
/// Used for fixed blocks (college, gym, commute), floating allocations
/// (SWE, CAT, etc.), and deviation blocks.
library;

import 'package:equatable/equatable.dart';

/// The type of a time block.
enum TimeBlockType {
  /// Immovable blocks: college, gym, commute.
  fixed,

  /// Algorithm-allocated blocks from floating targets.
  floating,

  /// User-added deviations (blockouts, extensions).
  deviation,
}

class TimeBlock extends Equatable {
  /// Unique identifier.
  final String id;

  /// Human-readable label (e.g., "College", "SWE Roadmap").
  final String label;

  /// Day of the week (1=Monday .. 7=Sunday).
  final int dayOfWeek;

  /// Start time as minutes since midnight (e.g., 600 = 10:00 AM).
  final int startMinutes;

  /// End time as minutes since midnight.
  final int endMinutes;

  /// The category of this block.
  final TimeBlockType type;

  /// For floating blocks, links back to the TaskTarget ID.
  final String? parentTargetId;

  const TimeBlock({
    required this.id,
    required this.label,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.type,
    this.parentTargetId,
  });

  /// Duration in minutes.
  int get durationMinutes => endMinutes - startMinutes;

  /// Creates a copy with optional overrides.
  TimeBlock copyWith({
    String? id,
    String? label,
    int? dayOfWeek,
    int? startMinutes,
    int? endMinutes,
    TimeBlockType? type,
    String? parentTargetId,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      label: label ?? this.label,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      type: type ?? this.type,
      parentTargetId: parentTargetId ?? this.parentTargetId,
    );
  }

  @override
  List<Object?> get props =>
      [id, label, dayOfWeek, startMinutes, endMinutes, type, parentTargetId];

  @override
  String toString() =>
      'TimeBlock($label, day=$dayOfWeek, $startMinutes-$endMinutes, $type)';
}
