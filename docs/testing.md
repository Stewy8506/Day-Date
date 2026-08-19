# Testing & Quality Assurance Reference

**Path**: `test/`

Day-Date maintains a unit test suite verifying time utilities, the core scheduling algorithm, edge cases, constraint satisfaction, and dynamic cancellation behaviors.

---

## Test Directory Structure

```
test/
├── core/
│   └── time_utils_test.dart               # Time calculation & slot tests (12 tests)
└── features/
    └── schedule/
        └── application/
            └── planner_service_test.dart  # Algorithm & cancellation tests (36 tests)
```

---

## Test Suites

### 1. `time_utils_test.dart` (12 tests)
Verifies core arithmetic and interval handling:
- **`overlaps`**: Tests overlapping ranges, contained intervals, disjoint sets, and touching boundaries.
- **`formatMinutes`**: Tests midnight (`12:00 AM`), noon (`12:00 PM`), morning, and evening conversions.
- **`formatDuration`**: Tests 0m, 45m, 60m (`1h`), 90m (`1h 30m`), and multi-hour durations.
- **`timeToMinutes`**: Tests conversion from 24h clock to minute integers.
- **`computeFreeSlots`**:
  - Full day free with zero occupied blocks.
  - Multi-gap splitting around occupied blocks.
  - Sub-90-minute gap filtering.

---

### 2. `planner_service_test.dart` (36 tests)

#### A. Baseline Schedule Validation (7 tests)
- **7-day generation**: Ensures all 7 days are keyed in `dailySchedule`.
- **No overlaps**: Checks that `blocks[i].end <= blocks[i+1].start` across every day.
- **90-minute minimum duration**: Verifies that every single generated floating block has `duration >= 90`.
- **Daily caps enforcement**: Verifies that no target exceeds its daily maximum limit on any individual day.
- **Quota fulfillment**: Checks that targets fulfill their weekly quota without shortfall warnings when sufficient free time exists.
- **Fixed block integrity**: Confirms fixed commitments remain intact and unmodified in the output.
- **Affinity biasing**: Verifies morning affinity goals (e.g. CAT Prep) are biased before noon.

#### B. Deviation Handling (6 tests)
- **Blockout deviation**: Verifies that adding an appointment/outing removes free time and floating tasks do not overlap with it.
- **Overflow redistribution**: Verifies that blocking out a full day shifts floating tasks to other days.
- **Extension deviation**: Tests extending an existing commitment and shifting the commute.
- **Underfill warning**: Tests that heavily blocking the week generates appropriate `AllocationWarning` instances with accurate shortfall hours.
- **Empty deviations**: Confirms that empty deviation lists produce identical schedules to baseline.

#### C. Edge Cases (3 tests)
- **No fixed blocks**: Verifies scheduling still runs and allocates floating blocks when no fixed blocks exist.
- **No targets**: Verifies output contains only fixed blocks without crashing or warnings.
- **Overlapping fixed blocks**: Handles malformed input gracefully.

#### D. College Off / Cancellation — `accelerateWeek` (8 tests)
- **Removal of commitments**: Fixed commitments and commute blocks on the off-day are stripped.
- **Filling opened hours**: Verifies floating tasks populate the newly freed time window.
- **Affinity in freed time**: Verifies morning goals take the morning freed slot and afternoon goals take the afternoon freed slot.
- **Daily caps maintained**: Verifies targets do not exceed daily limits even with all-day free time.
- **Weekend / later-week reduction**: Verifies that fulfilling goals early on the off-day frees up the upcoming weekend.
- **90-minute minimums**: Verifies all new blocks adhere to the minimum duration.
- **Gym preserved**: Verifies unrelated evening fixed blocks remain intact.

#### E. College Off / Cancellation — `restAndLeisure` (3 tests)
- **Free Time replacement**: Verifies that a `"Free Time"` block replaces the recurring commitment from commute start to commute end.
- **No floating allocation in freed slot**: Verifies study/project goals are not scheduled in the leisure window.
- **Rest of week unchanged**: Confirms subsequent days maintain their baseline load.

#### F. Toggle Restore (1 test)
- **Restoring attendance**: Verifies that deleting/toggling off the cancellation deviation returns the schedule to the exact baseline state.

---

## Running the Tests

### Execute full test suite:
```bash
flutter test
```

### Run a specific test file:
```bash
flutter test test/features/schedule/application/planner_service_test.dart
```

### Run with coverage output:
```bash
flutter test --coverage
```

### Run static analysis:
```bash
flutter analyze
```

---

## How to Add New Tests

When adding a new feature or constraint to `PlannerService`:
1. Use test helpers in `planner_service_test.dart` (`_createSeedFixedBlocks()`, `_createSeedTargets()`).
2. Add a `test('description', () { ... })` under the appropriate `group`.
3. Assert both:
   - Positive behavior (the new constraint is satisfied).
   - Invariant preservation (no overlaps, all blocks ≥ 90m, daily caps respected).
