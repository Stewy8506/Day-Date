/// Schedule-wide constants for the Day-Date engine.
library;

/// Minimum duration (in minutes) for a floating target block.
const int kMinBlockMinutes = 30;

/// Day boundaries (minutes since midnight).
const int kWeekdayStartMinutes = 450; // 07:30 AM (Monday - Friday with College)
const int kCollegeOffStartMinutes = 540; // 09:00 AM (Monday - Friday when College is Off)
const int kWeekendStartMinutes = 540; // 09:00 AM (Saturday - Sunday)
const int kDayStartMinutes = 450; // default baseline (07:30 AM)
const int kDayEndMinutes = 1440; // 12:00 AM midnight

/// Inter-session rest breaks between consecutive focus activities.
const int kWeekendInterSessionBreakMinutes = 30; // 30-min break on weekends
const int kWeekdayInterSessionBreakMinutes = 15; // 15-min break on weekdays

/// Compressed breaks used when the schedule engine is under allocation pressure.
const int kPressureWeekendBreakMinutes = 15; // 15-min break on weekends under pressure
const int kPressureWeekdayBreakMinutes = 10; // 10-min break on weekdays under pressure

/// Minimum lunch duration when under pressure.
const int kPressureLunchMinutes = 45; // 45-min lunch under pressure

/// Mandatory transition buffers (minutes)
const int kPreCollegeBufferMinutes = 20; // 20-min buffer before College & Commute
const int kPreGymBufferMinutes = 20; // 20-min buffer before Gym
const int kPostGymBufferMinutes = 30; // 30-min buffer after Gym for shower/dinner/cooldown
const int kPostCollegeBufferMinutes = 30; // 30-min buffer after College return

/// Time affinity window boundaries (minutes since midnight).
const int kMorningStart = 450; // 07:30 AM
const int kMorningEnd = 840; // 02:00 PM (pre-lunch focus window)
const int kAfternoonStart = 840; // 02:00 PM
const int kAfternoonEnd = 1170; // 07:30 PM (pre-gym focus window)
const int kLateNightStart = 1290; // 09:30 PM / 10:00 PM
const int kLateNightEnd = 1440; // 12:00 AM midnight

/// Days of the week constants.
const int kMonday = 1;
const int kTuesday = 2;
const int kWednesday = 3;
const int kThursday = 4;
const int kFriday = 5;
const int kSaturday = 6;
const int kSunday = 7;

/// Human-readable day names.
const Map<int, String> kDayNames = {
  kMonday: 'Monday',
  kTuesday: 'Tuesday',
  kWednesday: 'Wednesday',
  kThursday: 'Thursday',
  kFriday: 'Friday',
  kSaturday: 'Saturday',
  kSunday: 'Sunday',
};

/// Hive box names.
const String kFixedBlocksBox = 'fixedBlocks';
const String kTaskTargetsBox = 'taskTargets';
const String kDeviationsBox = 'deviations';
const String kTaskCompletionsBox = 'taskCompletions';
const String kMetaBox = 'meta';
