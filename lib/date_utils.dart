// Small date helpers used throughout the app. Everything works on
// "date-only" DateTime values (midnight, local time) so equality and
// map-keying behave predictably.

const List<String> kMonthNames = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

const List<String> kMonthShort = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

const List<String> kWeekdayFull = [
  "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
];

const List<String> kWeekdayShort = [
  "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun",
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime todayDate() => dateOnly(DateTime.now());

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime addDays(DateTime d, int n) => dateOnly(d).add(Duration(days: n));

int daysBetween(DateTime a, DateTime b) =>
    dateOnly(b).difference(dateOnly(a)).inDays;

String pad2(int n) => n.toString().padLeft(2, "0");

/// Stable "yyyy-MM-dd" key, handy for map keys (habit logs, day stats).
String ymdKey(DateTime d) => "${d.year}-${pad2(d.month)}-${pad2(d.day)}";

String monthKeyOf(DateTime d) => "${d.year}-${pad2(d.month)}";

String monthLabelOf(String key) {
  final parts = key.split("-");
  final y = parts[0];
  final m = int.parse(parts[1]);
  return "${kMonthNames[m - 1]} $y";
}

String prettyDate(DateTime d) => "${kMonthShort[d.month - 1]} ${d.day}";

String prettyDateFull(DateTime d) =>
    "${kMonthNames[d.month - 1]} ${d.day}, ${d.year}";

/// Monday-first weekday index, 0..6 (Mon=0 .. Sun=6) — matches how the
/// recurring-task weekday picker stores days.
int mondayFirstIndex(DateTime d) => d.weekday - 1;

String weekdayFullOf(DateTime d) => kWeekdayFull[mondayFirstIndex(d)];

String weekdayShortOf(DateTime d) => kWeekdayShort[mondayFirstIndex(d)];

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return "Good night";
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

String timeLabel(int hour, int minute) {
  final ampm = hour >= 12 ? "pm" : "am";
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return "$h12:${pad2(minute)}$ampm";
}

/// Relative "x ago" label for notification timestamps.
String timeAgo(DateTime ts) {
  final diff = DateTime.now().difference(ts);
  if (diff.inSeconds < 60) return "just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  return "${diff.inDays}d ago";
}
