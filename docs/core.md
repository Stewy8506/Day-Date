# Core Layer Reference

**Path**: `lib/core/`

Shared utilities, constants, and error types used across all layers.

---

## `schedule_constants.dart`

**Path**: `lib/core/constants/schedule_constants.dart`

Global constants that parameterize the scheduling engine.

### Algorithm Parameters

| Constant | Type | Value | Description |
|:---------|:-----|:------|:------------|
| `kMinBlockMinutes` | `int` | `90` | Minimum duration for any floating block. Blocks shorter than this are never created. |
| `kDayStartMinutes` | `int` | `450` (7:30 AM) | Earliest time the engine considers for scheduling. |
| `kDayEndMinutes` | `int` | `1439` (11:59 PM) | Latest time the engine considers. |

### Time Affinity Windows

| Constant | Value | Window |
|:---------|:------|:-------|
| `kMorningStart` / `kMorningEnd` | `450` / `720` | 7:30 AM – 12:00 PM |
| `kAfternoonStart` / `kAfternoonEnd` | `720` / `1140` | 12:00 PM – 7:00 PM |
| `kLateNightStart` / `kLateNightEnd` | `1290` / `1439` | 9:30 PM – 11:59 PM |

### Day Constants

| Constant | Value |
|:---------|:------|
| `kMonday` .. `kSunday` | `1` .. `7` |
| `kDayNames` | `Map<int, String>` — `{1: 'Monday', ..., 7: 'Sunday'}` |

### Hive Box Names

| Constant | Value | Stores |
|:---------|:------|:-------|
| `kFixedBlocksBox` | `'fixedBlocks'` | `TimeBlockModel` instances |
| `kTaskTargetsBox` | `'taskTargets'` | `TaskTargetModel` instances |
| `kDeviationsBox` | `'deviations'` | `ScheduleDeviationModel` instances |
| `kMetaBox` | `'meta'` | Dynamic key-value pairs (e.g., `'seeded'` flag) |

---

## `failures.dart`

**Path**: `lib/core/error/failures.dart`

Sealed failure hierarchy for typed error handling.

### `Failure` (sealed base class)

| Field | Type | Description |
|:------|:-----|:------------|
| `message` | `String` | Human-readable error description |

### Subclasses

| Class | When Used |
|:------|:----------|
| `DatabaseFailure` | Hive read/write operations fail |
| `SeedFailure` | First-launch seed data population fails |
| `AllocationFailure` | Schedule computation encounters an unrecoverable state |

---

## `time_utils.dart`

**Path**: `lib/core/utils/time_utils.dart`

Pure Dart utility functions for time manipulation. No Flutter imports.

### `FreeSlot` class

Represents a gap of unoccupied time on a specific day. Used internally by `PlannerService` during allocation.

| Field | Type | Mutable? | Description |
|:------|:-----|:---------|:------------|
| `dayOfWeek` | `int` | No | Day of the week (1–7) |
| `startMinutes` | `int` | **Yes** | Start of the free gap (minutes since midnight). Mutated during allocation as blocks consume the slot. |
| `endMinutes` | `int` | No | End of the free gap |

| Getter | Returns | Description |
|:-------|:--------|:------------|
| `duration` | `int` | `endMinutes - startMinutes` — remaining available minutes |

### Functions

#### `overlaps(int s1, int e1, int s2, int e2) → bool`

Returns `true` if two half-open intervals `[s1, e1)` and `[s2, e2)` overlap.

```dart
overlaps(600, 720, 700, 800)  // true  — ranges share 700-720
overlaps(600, 700, 700, 800)  // false — adjacent, no overlap
overlaps(600, 700, 800, 900)  // false — disjoint
```

#### `formatMinutes(int minutes) → String`

Converts minutes-since-midnight to a 12-hour AM/PM string.

```dart
formatMinutes(0)    // '12:00 AM'
formatMinutes(600)  // '10:00 AM'
formatMinutes(720)  // '12:00 PM'
formatMinutes(810)  // '1:30 PM'
```

#### `formatDuration(int minutes) → String`

Converts a duration in minutes to a compact human-readable string.

```dart
formatDuration(0)    // '0m'
formatDuration(45)   // '45m'
formatDuration(60)   // '1h'
formatDuration(90)   // '1h 30m'
formatDuration(150)  // '2h 30m'
```

#### `timeToMinutes(int hour, int minute) → int`

Converts a 24-hour time to minutes-since-midnight.

```dart
timeToMinutes(10, 0)   // 600
timeToMinutes(13, 50)  // 830
```

#### `computeFreeSlots({...}) → List<FreeSlot>`

Computes all free time gaps between occupied blocks on a given day.

**Parameters:**

| Parameter | Type | Description |
|:----------|:-----|:------------|
| `dayOfWeek` | `int` | Day for the generated `FreeSlot` objects |
| `occupied` | `List<({int start, int end})>` | **Must be sorted by start**. Occupied time ranges. |
| `dayStart` | `int` | Earliest schedulable minute (typically `kDayStartMinutes`) |
| `dayEnd` | `int` | Latest schedulable minute (typically `kDayEndMinutes`) |
| `minSlotMinutes` | `int` | Minimum gap size to include (typically `kMinBlockMinutes`) |

**Returns**: List of `FreeSlot` objects for gaps ≥ `minSlotMinutes` between the occupied ranges.

**Algorithm**:
1. Start a cursor at `dayStart`.
2. For each occupied block: if block start > cursor, the gap is a potential free slot.
3. Advance cursor to `max(cursor, block.end)`.
4. After all blocks, check remaining time until `dayEnd`.
5. Filter out gaps < `minSlotMinutes`.

```dart
computeFreeSlots(
  dayOfWeek: 1,
  occupied: [(start: 600, end: 720), (start: 1170, end: 1290)],
  dayStart: 360,
  dayEnd: 1439,
  minSlotMinutes: 90,
)
// Returns: [FreeSlot(360-600), FreeSlot(720-1170), FreeSlot(1290-1439)]
```
