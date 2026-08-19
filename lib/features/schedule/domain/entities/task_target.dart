/// A weekly floating target with a quota, time affinity, and daily cap.
library;

import 'package:equatable/equatable.dart';

/// Defines the preferred time-of-day window for a floating target.
enum TimeAffinity {
  /// 06:00 – 12:00 (e.g., CAT Prep).
  morning,

  /// 12:00 – 19:00 (e.g., SWE Roadmap).
  afternoon,

  /// 21:30 – 23:59 (e.g., Freelancing).
  lateNight,

  /// Any free slot (e.g., ECE Upkeep).
  flexible,
}

class TaskTarget extends Equatable {
  /// Unique identifier.
  final String id;

  /// Human-readable name (e.g., "SWE Roadmap").
  final String name;

  /// Total weekly hours to allocate.
  final double weeklyHours;

  /// Priority for allocation order (1 = highest).
  final int priority;

  /// Preferred time-of-day window.
  final TimeAffinity affinity;

  /// Maximum hours to allocate on any single day.
  final double dailyCapHours;

  const TaskTarget({
    required this.id,
    required this.name,
    required this.weeklyHours,
    required this.priority,
    required this.affinity,
    required this.dailyCapHours,
  });

  /// Weekly quota in minutes.
  int get weeklyMinutes => (weeklyHours * 60).round();

  /// Daily cap in minutes.
  int get dailyCapMinutes => (dailyCapHours * 60).round();

  TaskTarget copyWith({
    String? id,
    String? name,
    double? weeklyHours,
    int? priority,
    TimeAffinity? affinity,
    double? dailyCapHours,
  }) {
    return TaskTarget(
      id: id ?? this.id,
      name: name ?? this.name,
      weeklyHours: weeklyHours ?? this.weeklyHours,
      priority: priority ?? this.priority,
      affinity: affinity ?? this.affinity,
      dailyCapHours: dailyCapHours ?? this.dailyCapHours,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, weeklyHours, priority, affinity, dailyCapHours];

  @override
  String toString() =>
      'TaskTarget($name, ${weeklyHours}h/wk, priority=$priority, $affinity, cap=${dailyCapHours}h/day)';
}
