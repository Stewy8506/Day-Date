/// Schedule-wide constants for the Day-Date engine.
library;

/// Minimum duration (in minutes) for a floating target block.
const int kMinBlockMinutes = 90;

/// Day boundaries (minutes since midnight).
const int kDayStartMinutes = 450; // 07:30 AM
const int kDayEndMinutes = 1439; // 23:59 PM

/// Time affinity window boundaries (minutes since midnight).
const int kMorningStart = 450; // 07:30 AM
const int kMorningEnd = 720; // 12:00 PM
const int kAfternoonStart = 720; // 12:00
const int kAfternoonEnd = 1140; // 19:00
const int kLateNightStart = 1290; // 21:30
const int kLateNightEnd = 1439; // 23:59

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
const String kMetaBox = 'meta';
