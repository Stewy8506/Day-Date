import 'package:equatable/equatable.dart';

/// Tracks completion status and logged duration for a scheduled task or block.
class TaskCompletion extends Equatable {
  final String id;
  final String blockId;
  final String? targetId;
  final int dayOfWeek;
  final String dateString; // YYYY-MM-DD
  final bool isCompleted;
  final int scheduledMinutes;
  final int actualMinutes;
  final DateTime updatedAt;

  const TaskCompletion({
    required this.id,
    required this.blockId,
    this.targetId,
    required this.dayOfWeek,
    required this.dateString,
    required this.isCompleted,
    required this.scheduledMinutes,
    required this.actualMinutes,
    required this.updatedAt,
  });

  TaskCompletion copyWith({
    String? id,
    String? blockId,
    String? targetId,
    int? dayOfWeek,
    String? dateString,
    bool? isCompleted,
    int? scheduledMinutes,
    int? actualMinutes,
    DateTime? updatedAt,
  }) {
    return TaskCompletion(
      id: id ?? this.id,
      blockId: blockId ?? this.blockId,
      targetId: targetId ?? this.targetId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dateString: dateString ?? this.dateString,
      isCompleted: isCompleted ?? this.isCompleted,
      scheduledMinutes: scheduledMinutes ?? this.scheduledMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        blockId,
        targetId,
        dayOfWeek,
        dateString,
        isCompleted,
        scheduledMinutes,
        actualMinutes,
        updatedAt,
      ];
}
