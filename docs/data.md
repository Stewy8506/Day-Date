# Data Layer Reference

**Path**: `lib/features/schedule/data/`

The data layer handles offline persistence using **Hive CE** (Community Edition). It translates raw database records into clean domain entities through bidirectional mappers and exposes a repository implementation.

---

## Directory Structure

```
lib/features/schedule/data/
├── datasources/
│   └── local_schedule_datasource.dart # Direct Hive box wrapper with change streams
├── models/
│   ├── time_block_model.dart          # Hive model for TimeBlock (typeId: 0)
│   ├── task_target_model.dart         # Hive model for TaskTarget (typeId: 1)
│   ├── schedule_deviation_model.dart  # Hive model for ScheduleDeviation (typeId: 2)
│   └── model_mappers.dart             # Extension methods (toEntity & toModel)
└── repositories/
    └── schedule_repository_impl.dart  # ScheduleRepository implementation with seed data
```

---

## Hive Type ID Registry

Every persisted model and enum has a unique `@HiveType(typeId: N)`:

| Type Name | Type ID | Model File | Description |
|:----------|:--------|:-----------|:------------|
| `TimeBlockModel` | `0` | `time_block_model.dart` | Persistent time block record |
| `TaskTargetModel` | `1` | `task_target_model.dart` | Persistent weekly target goal |
| `ScheduleDeviationModel` | `2` | `schedule_deviation_model.dart` | Persistent deviation record |
| `TimeBlockTypeModel` | `3` | `time_block_model.dart` | Enum: `fixed`, `floating`, `deviation` |
| `DeviationTypeModel` | `4` | `schedule_deviation_model.dart` | Enum: `blockout`, `extension`, `collegeCancellation` |
| `TimeAffinityModel` | `5` | `task_target_model.dart` | Enum: `morning`, `afternoon`, `lateNight`, `flexible` |
| `OffDayStrategyModel` | `6` | `schedule_deviation_model.dart` | Enum: `accelerateWeek`, `restAndLeisure` |

---

## Models & Hive Annotations

### 1. `TimeBlockModel` (`typeId: 0`)

```dart
@HiveType(typeId: 0)
class TimeBlockModel extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String label;
  @HiveField(2) late int dayOfWeek;
  @HiveField(3) late int startMinutes;
  @HiveField(4) late int endMinutes;
  @HiveField(5) late TimeBlockTypeModel typeModel;
  @HiveField(6) String? parentTargetId;
}
```

### 2. `TaskTargetModel` (`typeId: 1`)

```dart
@HiveType(typeId: 1)
class TaskTargetModel extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String name;
  @HiveField(2) late double weeklyHours;
  @HiveField(3) late int priority;
  @HiveField(4) late TimeAffinityModel affinityModel;
  @HiveField(5) late double dailyCapHours;
}
```

### 3. `ScheduleDeviationModel` (`typeId: 2`)

```dart
@HiveType(typeId: 2)
class ScheduleDeviationModel extends HiveObject {
  @HiveField(0) late String id;
  @HiveField(1) late String label;
  @HiveField(2) late DeviationTypeModel typeModel;
  @HiveField(3) late int dayOfWeek;
  @HiveField(4) late int startMinutes;
  @HiveField(5) late int endMinutes;
  @HiveField(6) String? extendsBlockId;
  @HiveField(7) int? extensionMinutes;
  @HiveField(8) OffDayStrategyModel? offDayStrategyModel;
  @HiveField(9) DateTime? date;
}
```

---

## Model Mappers (`model_mappers.dart`)

The mapping layer converts between domain entities and Hive persistence models to keep the domain clean.

### Extensions Provided:
1. `TimeBlockModelMapper` & `TimeBlockEntityMapper`:
   - `TimeBlockModel.toEntity() → TimeBlock`
   - `TimeBlock.toModel() → TimeBlockModel`
2. `TaskTargetModelMapper` & `TaskTargetEntityMapper`:
   - `TaskTargetModel.toEntity() → TaskTarget`
   - `TaskTarget.toModel() → TaskTargetModel`
3. `ScheduleDeviationModelMapper` & `ScheduleDeviationEntityMapper`:
   - `ScheduleDeviationModel.toEntity() → ScheduleDeviation`
   - `ScheduleDeviation.toModel() → ScheduleDeviationModel`

---

## Local Schedule Datasource (`local_schedule_datasource.dart`)

Encapsulates direct operations on the Hive boxes.

### Core Methods:
- **`getFixedBlocks()`**: Reads all `TimeBlockModel`s from `Box<TimeBlockModel>('fixedBlocks')`.
- **`getTaskTargets()`**: Reads all `TaskTargetModel`s from `Box<TaskTargetModel>('taskTargets')`.
- **`getDeviations()`**: Reads all `ScheduleDeviationModel`s from `Box<ScheduleDeviationModel>('deviations')`.
- **`addDeviation(model)` / `removeDeviation(id)`**: Inserts or deletes deviation records.
- **`seedFixedBlocks(blocks)` / `seedTaskTargets(targets)`**: Batch saves initial seed data.
- **`isSeeded()` / `markSeeded()`**: Manages the first-launch boolean flag in `Box('meta')`.
- **`watchAllChanges() → Stream<void>`**: Merges `.watch()` streams from all 3 data boxes into a unified broadcast stream.

```dart
Stream<void> watchAllChanges() {
  final controller = StreamController<void>.broadcast();
  final sub1 = _fixedBlocksBox.watch().listen((_) => controller.add(null));
  final sub2 = _taskTargetsBox.watch().listen((_) => controller.add(null));
  final sub3 = _deviationsBox.watch().listen((_) => controller.add(null));
  ...
}
```

---

## Schedule Repository Implementation (`schedule_repository_impl.dart`)

Implements `ScheduleRepository` by connecting `LocalScheduleDatasource` to domain interfaces.

### 1. `seedIfEmpty()`
- Checks `_datasource.isSeeded()`. If `true`, aborts immediately.
- If first launch, generates initial baseline routine and weekly targets using UUIDs.
- Writes to local storage and sets the `'seeded'` flag in `meta` box to `true`.

### 2. `setCollegeStatusForDate(DateTime date, ...)`
- Computes `dayOfWeek = date.weekday`.
- If `isAttending == false`:
  - Creates a `ScheduleDeviationModel` with `typeModel: DeviationTypeModel.collegeCancellation`.
  - Attaches `date` and `offDayStrategyModel`.
  - Saves to database.
- If `isAttending == true`:
  - Queries deviations matching `collegeCancellation` on `dayOfWeek` and matching date.
  - Deletes them from database.

---

## Model Update Checklist

When modifying or adding database fields:
1. Increment or assign unique `@HiveField(n)` index in the target model.
2. Run code generation:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
3. Update `model_mappers.dart` to map the new field in both directions (`toEntity` and `toModel`).
4. Update `hive_registrar.g.dart` if a new `@HiveType` was created (handled automatically by `build_runner`).
