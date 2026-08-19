# Day-Date — Dynamic Scheduling Engine

A Flutter application implementing a dynamic weekly scheduling engine with **Clean Architecture**, **Riverpod** state management, and **Hive CE** local persistence. All data is stored offline — no network dependency.

## Tech Stack

| Layer | Technology |
|:------|:-----------|
| Framework | Flutter 3.41.2 / Dart 3.11.0 |
| State Management | Riverpod (Generator) |
| Local Storage | Hive CE (Community Edition) |
| Architecture | Clean Architecture (Domain → Data → Application → Presentation) |
| Testing | flutter_test |

## Architecture Overview

```
lib/
├── core/
│   ├── constants/     # Schedule constants, Hive box names
│   ├── error/         # Failure types (sealed hierarchy)
│   └── utils/         # Time utilities (overlap, formatting, free slots)
│
├── features/
│   └── schedule/
│       ├── domain/
│       │   ├── entities/      # TimeBlock, TaskTarget, ScheduleDeviation
│       │   ├── repositories/  # Abstract ScheduleRepository interface
│       │   └── usecases/      # SeedInitialData, AddDeviation, GetWeeklySchedule
│       │
│       ├── data/
│       │   ├── models/        # Hive-annotated models + bidirectional mappers
│       │   ├── datasources/   # LocalScheduleDatasource (Hive CRUD + watch)
│       │   └── repositories/  # ScheduleRepositoryImpl (seed, college status)
│       │
│       ├── application/
│       │   ├── services/      # PlannerService (core algorithm)
│       │   └── providers/     # Riverpod providers (reactive stream)
│       │
│       └── presentation/
│           ├── screens/       # WeeklyOverviewScreen, DailyDetailScreen
│           └── widgets/       # TimeBlockCard, DayColumn, AddDeviationSheet
│
├── hive_registrar.g.dart      # Generated Hive adapter registry
└── main.dart                  # App bootstrap
```

## Data Models

### TimeBlock

Represents a scheduled time slot on a specific day.

| Field | Type | Description |
|:------|:-----|:------------|
| `id` | `String` | Unique identifier |
| `label` | `String` | Display name (e.g., "College", "SWE Roadmap") |
| `dayOfWeek` | `int` | 1=Monday .. 7=Sunday |
| `startMinutes` | `int` | Start time as minutes since midnight |
| `endMinutes` | `int` | End time as minutes since midnight |
| `type` | `TimeBlockType` | `fixed`, `floating`, or `deviation` |
| `parentTargetId` | `String?` | Links floating blocks to their TaskTarget |

### TaskTarget

A weekly study/work goal that the planner distributes across free time.

| Field | Type | Description |
|:------|:-----|:------------|
| `id` | `String` | Unique identifier |
| `name` | `String` | Display name (e.g., "CAT Prep") |
| `weeklyHours` | `double` | Target hours per week |
| `priority` | `int` | 1 = highest priority |
| `affinity` | `TimeAffinity` | Preferred time window |
| `dailyCapHours` | `double` | Maximum hours per day to prevent clustering |

### ScheduleDeviation

A user-reported change to the baseline schedule.

| Field | Type | Description |
|:------|:-----|:------------|
| `id` | `String` | Unique identifier |
| `label` | `String` | Display name |
| `type` | `DeviationType` | `blockout`, `extension`, or `collegeCancellation` |
| `dayOfWeek` | `int` | 1=Monday .. 7=Sunday |
| `startMinutes` | `int` | Start (0 for college cancellations) |
| `endMinutes` | `int` | End (0 for college cancellations) |
| `offDayStrategy` | `OffDayStrategy?` | Re-balancing strategy for college cancellations |
| `date` | `DateTime?` | Specific calendar date for date-aware deviations |

## Seed Data (First Launch)

### Fixed Blocks — College Schedule

| Day | College | Commute Before | Commute After |
|:----|:--------|:---------------|:--------------|
| Monday | 10:00 AM – 1:50 PM | 9:30 AM – 10:00 AM | 1:50 PM – 2:30 PM |
| Tuesday | 10:00 AM – 4:20 PM | 9:30 AM – 10:00 AM | 4:20 PM – 5:00 PM |
| Wednesday | 10:50 AM – 2:30 PM | 10:20 AM – 10:50 AM | 2:30 PM – 3:10 PM |
| Thursday | 10:50 AM – 3:30 PM | 10:20 AM – 10:50 AM | 3:30 PM – 4:10 PM |
| Friday | 10:00 AM – 3:30 PM | 9:30 AM – 10:00 AM | 3:30 PM – 4:10 PM |

### Fixed Blocks — Gym

Monday through Saturday: **7:30 PM – 9:30 PM**

### Floating Targets

| Target | Weekly Hours | Priority | Affinity | Daily Cap |
|:-------|:------------|:---------|:---------|:----------|
| SWE Roadmap | 17.0h | 1 | Afternoon (12 PM – 7 PM) | 3.0h |
| CAT Prep | 11.5h | 2 | Morning (6 AM – 12 PM) | 2.5h |
| Freelancing | 10.0h | 3 | Late Night (9:30 PM – 12 AM) | 2.0h |
| ECE Upkeep | 6.0h | 4 | Flexible | 1.5h |

## Scheduling Algorithm — Bounded Interleaved Strategy

The `PlannerService` implements a multi-pass interleaved allocation algorithm:

### Step 1: Build Occupied Map

1. Collect all fixed blocks (college, commute, gym) per day.
2. Process **college cancellations** — remove College/Commute blocks for off-days.
   - `accelerateWeek`: freed time becomes available for floating allocation.
   - `restAndLeisure`: a "Free Time" block replaces the college range, preventing allocation.
3. Apply blockout deviations as occupied ranges.
4. Apply extension deviations by extending referenced fixed blocks.

### Step 2: Compute Free Slots

For each day, compute gaps between occupied blocks that are ≥ 90 minutes (minimum block size). Overlapping occupied ranges are merged before gap computation.

### Step 3: Multi-Pass Interleaved Allocation

```
REPEAT until no more progress:
  FOR each day (Mon → Sun):
    FOR each target (by priority):
      IF target weekly quota filled → skip
      IF target daily cap reached → skip

      Affinity pass: try preferred-window slots first
      Spillover pass: try remaining slots

      FOR each slot:
        Calculate allocation (min of: remaining quota, daily cap, slot size)
        Enforce ≥ 90-minute minimum block
        Create floating TimeBlock
        Consume slot capacity
```

### Step 4: Build Result

Combine fixed + floating + deviation blocks per day, sorted by start time. Emit warnings for any target whose weekly quota couldn't be fully filled.

## College Cancellation System

### Overview

When a college day is cancelled (bunking, holiday, sick day), the freed college + commute time is handled according to the chosen `OffDayStrategy`.

### API

```dart
// Mark Tuesday 2026-08-19 as college-off with accelerateWeek strategy
await repository.setCollegeStatusForDate(
  DateTime(2026, 8, 19),
  isAttending: false,
  strategy: OffDayStrategy.accelerateWeek,
);

// Restore attendance — removes the deviation and restores baseline
await repository.setCollegeStatusForDate(
  DateTime(2026, 8, 19),
  isAttending: true,
);
```

### Strategies

#### `accelerateWeek` (Default)

- Removes College + Commute blocks from the off-day.
- Freed hours become available free slots for the planner.
- The algorithm fills them following affinity + daily cap rules.
- Because weekly quotas are global, fulfilling more on the off-day means fewer hours needed on later days — the schedule naturally "scales down" the weekend.

#### `restAndLeisure`

- Removes College + Commute blocks from the off-day.
- Inserts a "Free Time" block spanning the same time range (commute-start to commute-end).
- This "Free Time" block acts as occupied space, preventing floating allocation.
- The rest of the week's schedule remains unchanged.

### Date Awareness

College cancellations are stored with a specific `DateTime date` for calendar-date awareness. This enables:
- Looking up whether a specific date is marked as off
- Distinguishing between two different Tuesdays
- Future: filtering deviations by week when computing a specific week's schedule

## Deviation System

| Type | Effect |
|:-----|:-------|
| **Blockout** | Blocks a time range (outing, appointment). Floating targets avoid this range. |
| **Extension** | Extends an existing fixed block (e.g., college runs 2 hours late). Shifts subsequent commute. |
| **College Cancellation** | Cancels college + commute for a date. Strategy determines if freed time is used productively or left free. |

## Running the App

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device
flutter run

# Run tests
flutter test

# Static analysis
flutter analyze
```

## Test Coverage

| Test Group | Tests | Description |
|:-----------|:------|:------------|
| Baseline Schedule | 7 | Schedule generation, overlaps, min blocks, caps, affinity |
| Deviation Handling | 6 | Blockout, extension, redistribution, underfill warnings |
| Edge Cases | 3 | No fixed blocks, no targets, overlapping fixed blocks |
| College Off (accelerateWeek) | 8 | Block removal, filling, affinity, caps, weekend reduction, overlaps, gym preserved |
| College Off (restAndLeisure) | 3 | Free Time insertion, no floating allocation, week unchanged |
| College Off (toggle) | 1 | Restore baseline after removing cancellation |
| Time Utils | 12 | Overlap detection, formatting, free slot computation |
| **Total** | **48** | All passing ✅ |

## Key Design Decisions

1. **Minutes-since-midnight** — All times stored as integers (e.g., 600 = 10:00 AM). Simpler arithmetic, no timezone issues.
2. **Day-of-week template** — The schedule is a weekly template (Mon=1 → Sun=7). Calendar-date awareness is layered on via `ScheduleDeviation.date`.
3. **Reactive recomputation** — Hive box `watch()` streams feed into a Riverpod `StreamProvider`. Any data change (deviation added/removed) triggers full schedule recomputation.
4. **Zero extra logic for accelerateWeek** — Simply removing College/Commute blocks opens free slots. The existing algorithm naturally discovers and fills them.
5. **90-minute minimum blocks** — Prevents fragmented micro-sessions that aren't productive.
6. **Daily caps** — Prevents over-clustering a single subject on one day.
