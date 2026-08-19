# Presentation Layer Reference

**Path**: `lib/features/schedule/presentation/`

The presentation layer is organized into a clean **multi-page application architecture** with an interactive tactile navigation shell (`AppShell`).

---

## Directory Structure

```
lib/features/schedule/presentation/
├── screens/
│   ├── app_shell.dart              # Main shell with tactile bottom navigation bar
│   ├── daily_schedule_page.dart    # Dedicated Day Timeline & quick college off toggle
│   ├── weekly_matrix_page.dart     # Full-screen 7-day routine overview & day inspect
│   ├── targets_dashboard_page.dart # Dedicated weekly goals, quotas & distribution tracking
│   └── deviations_manager_page.dart# Overrides, disruptions & college attendance matrix
└── widgets/
    ├── add_deviation_sheet.dart    # Modal bottom sheet form for deviations / cancellations
    ├── day_column.dart             # Tactile day selector capsule
    ├── tactile_interactive.dart    # Physics spring-scale feedback container
    └── time_block_card.dart        # Minimalist timeline card with duration badges
```

---

## Screen Catalog

### 1. `AppShell` (`app_shell.dart`)
Main root scaffold connecting the 4 dedicated pages:
- **Navigation Tabs**:
  - `Daily` (`Icons.calendar_today_rounded`): Immersive daily schedule & timeline.
  - `Week` (`Icons.view_week_rounded`): Full 7-day matrix inspector.
  - `Targets` (`Icons.track_changes_rounded`): Floating goals & weekly quota dashboard.
  - `Overrides` (`Icons.tune_rounded`): College status matrix & custom deviations.
- **Micro-Interactions**: Tactile spring-scale compression on tab press with active capsule highlight.

---

### 2. `DailySchedulePage` (`daily_schedule_page.dart`)
Dedicated full-screen timeline for inspecting and adjusting a single day:
- **7-Day Selector Strip**: Horizontal day-switch carousel with `DayColumn` pills.
- **Day Subheader**: Active day name, block count, total scheduled duration, and a one-tap **"College Off" / "Attending" toggle chip**.
- **Full-Bleed Timeline**: Smooth scrollable list of `TimeBlockCard`s with zero nested scrolling conflicts.

---

### 3. `WeeklyMatrixPage` (`weekly_matrix_page.dart`)
Full-screen 7-day routine inspector:
- **Weekly Metrics**: Total hours scheduled and 7-day balance indicator.
- **7-Day Card List**: Displays day cards (Monday through Sunday) with block chips and duration breakdowns.
- **Tap-to-Inspect**: Tapping any day card immediately selects that day and switches to the `Daily` page.

---

### 4. `TargetsDashboardPage` (`targets_dashboard_page.dart`)
Dedicated analytics hub for monitoring floating goals:
- **Overall Fulfillment Progress Bar**: Total scheduled hours vs. weekly quota (e.g. `44.5h / 44.5h • 100%`).
- **Target Cards**: Individual cards for each target (`SWE Roadmap`, `CAT Prep`, `Freelancing`, `ECE Upkeep`):
  - Progress bar & percentage.
  - Priority badge (`P1`, `P2`, etc.).
  - Time affinity window tag (e.g., `Morning 7:30 AM – 12 PM`).
  - Daily cap badge (`3.0h/day max`).
  - 7-day allocation breakdown matrix.

---

### 5. `DeviationsManagerPage` (`deviations_manager_page.dart`)
Central hub for managing schedule disruptions:
- **College Attendance Matrix**: Mon–Fri list with one-tap status toggles (`Attending` ↔ `College Off`) and strategy indicators (`Accelerate Week` / `Rest & Leisure`).
- **Active Deviations List**: Custom blockouts and extensions with one-tap delete button for instant schedule re-balancing.
- **Launcher**: Quick access to open `AddDeviationSheet`.

---

## Interactive Widgets

### 1. `Tactile` (`tactile_interactive.dart`)
A physics-based spring container providing responsive touch feedback:
- Scales down to `0.965` on tap down.
- Springs back with `Curves.easeOutBack` (110ms) on tap release or cancellation.

### 2. `TimeBlockCard` (`time_block_card.dart`)
Warm minimalist card:
- Left hairline accent indicator (warm amber for deep work, brushed steel for anchors, terracotta for deviations, sage for leisure).
- Category overline tag (`FOCUS`, `ANCHOR`, `OVERRIDE`, `LEISURE`).
- Card title and monospace time range (`07:30 — 09:30`).
- Compact duration badge.

### 3. `DayColumn` (`day_column.dart`)
Tactile day capsule in the day selector:
- Uppercase day abbreviation (`MON`, `TUE`).
- Circular block count badge.
- Scheduled duration in hours (`6.0h`).
