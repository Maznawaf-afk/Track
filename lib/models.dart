import 'date_utils.dart';

/// Looks up an enum value by its `.name`, falling back safely instead of
/// throwing when old/corrupt data is loaded from disk.
T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

String? dtToJson(DateTime? d) => d?.toIso8601String();
DateTime? dtFromJson(dynamic v) => v == null ? null : DateTime.parse(v as String);

// ───────────────────────── enums ─────────────────────────

enum Difficulty { easy, normal, hard }

extension DifficultyX on Difficulty {
  /// Lower sorts first: hard tasks are the ones you want surfaced.
  int get rank => this == Difficulty.hard ? 0 : (this == Difficulty.normal ? 1 : 2);
  String get label => switch (this) {
        Difficulty.easy => "Easy",
        Difficulty.normal => "Normal",
        Difficulty.hard => "Hard",
      };
  String get dot => switch (this) {
        Difficulty.easy => "🟢",
        Difficulty.normal => "🟠",
        Difficulty.hard => "🔥",
      };
}

enum TaskCategory { study, health, work, personal, other }

extension TaskCategoryX on TaskCategory {
  String get emoji => switch (this) {
        TaskCategory.study => "🎓",
        TaskCategory.health => "💪",
        TaskCategory.work => "💼",
        TaskCategory.personal => "🏠",
        TaskCategory.other => "•",
      };
  String get label => switch (this) {
        TaskCategory.study => "Study",
        TaskCategory.health => "Health",
        TaskCategory.work => "Work",
        TaskCategory.personal => "Personal",
        TaskCategory.other => "Other",
      };
}

enum TaskStatus { pending, working, done }

extension TaskStatusX on TaskStatus {
  int get rank => this == TaskStatus.working ? 0 : (this == TaskStatus.pending ? 1 : 2);
  String get label => switch (this) {
        TaskStatus.pending => "Pending",
        TaskStatus.working => "Working",
        TaskStatus.done => "Done",
      };
}

enum TaskBucket { sooner, later }

enum RecurrenceType { none, daily, weekly }

enum EventPriority { low, normal, high }

extension EventPriorityX on EventPriority {
  String get label => switch (this) {
        EventPriority.low => "Low",
        EventPriority.normal => "Normal",
        EventPriority.high => "High",
      };
}

enum ReviewMood { bad, okay, great }

extension ReviewMoodX on ReviewMood {
  String get emoji => switch (this) {
        ReviewMood.bad => "😞",
        ReviewMood.okay => "🙂",
        ReviewMood.great => "🔥",
      };
  String get label => switch (this) {
        ReviewMood.bad => "Bad",
        ReviewMood.okay => "Okay",
        ReviewMood.great => "Great",
      };
}

enum FocusStyle { deepWork, balanced, flexible }

extension FocusStyleX on FocusStyle {
  String get label => switch (this) {
        FocusStyle.deepWork => "Deep work",
        FocusStyle.balanced => "Balanced",
        FocusStyle.flexible => "Flexible",
      };
  String get description => switch (this) {
        FocusStyle.deepWork => "Long, uninterrupted sessions.",
        FocusStyle.balanced => "Steady sessions with regular breaks.",
        FocusStyle.flexible => "Short bursts, easy to fit anywhere.",
      };
  int get pomodoroMinutes => switch (this) {
        FocusStyle.deepWork => 45,
        FocusStyle.balanced => 25,
        FocusStyle.flexible => 15,
      };
}

// ───────────────────────── recurrence ─────────────────────────

class RecurrenceRule {
  RecurrenceType type;
  /// Monday-first weekday indices (0=Mon .. 6=Sun), used when [type] is weekly.
  List<int> weekdays;

  RecurrenceRule({this.type = RecurrenceType.none, List<int>? weekdays})
      : weekdays = weekdays ?? [];

  bool matches(DateTime day) {
    switch (type) {
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return weekdays.contains(mondayFirstIndex(day));
      case RecurrenceType.none:
        return false;
    }
  }

  String get label {
    if (type == RecurrenceType.daily) return "Every day";
    if (type == RecurrenceType.weekly) {
      if (weekdays.isEmpty) return "Weekly";
      final names = (List.of(weekdays)..sort()).map((i) => kWeekdayShort[i]).join(" ");
      return "Every $names";
    }
    return "Doesn't repeat";
  }

  Map<String, dynamic> toJson() => {"type": type.name, "weekdays": weekdays};

  factory RecurrenceRule.fromJson(Map<String, dynamic> j) => RecurrenceRule(
        type: enumByName(RecurrenceType.values, j["type"] as String?, RecurrenceType.none),
        weekdays: (j["weekdays"] as List?)?.map((e) => e as int).toList() ?? [],
      );
}

class RecurringTemplate {
  String id;
  String text;
  Difficulty difficulty;
  TaskCategory category;
  TaskBucket bucket;
  RecurrenceRule rule;

  RecurringTemplate({
    required this.id,
    required this.text,
    this.difficulty = Difficulty.normal,
    this.category = TaskCategory.other,
    this.bucket = TaskBucket.sooner,
    required this.rule,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "text": text,
        "difficulty": difficulty.name,
        "category": category.name,
        "bucket": bucket.name,
        "rule": rule.toJson(),
      };

  factory RecurringTemplate.fromJson(Map<String, dynamic> j) => RecurringTemplate(
        id: j["id"] as String,
        text: j["text"] as String,
        difficulty: enumByName(Difficulty.values, j["difficulty"] as String?, Difficulty.normal),
        category: enumByName(TaskCategory.values, j["category"] as String?, TaskCategory.other),
        bucket: enumByName(TaskBucket.values, j["bucket"] as String?, TaskBucket.sooner),
        rule: RecurrenceRule.fromJson((j["rule"] as Map).cast<String, dynamic>()),
      );
}

// ───────────────────────── task ─────────────────────────

class TaskItem {
  String id;
  String text;
  Difficulty difficulty;
  TaskCategory category;
  TaskBucket bucket;
  TaskStatus status;
  DateTime date;
  DateTime? dueDate;
  DateTime? completedAt;
  bool carried;
  String? recurringId;

  TaskItem({
    required this.id,
    required this.text,
    this.difficulty = Difficulty.normal,
    this.category = TaskCategory.other,
    this.bucket = TaskBucket.sooner,
    this.status = TaskStatus.pending,
    required this.date,
    this.dueDate,
    this.completedAt,
    this.carried = false,
    this.recurringId,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "text": text,
        "difficulty": difficulty.name,
        "category": category.name,
        "bucket": bucket.name,
        "status": status.name,
        "date": dtToJson(date),
        "dueDate": dtToJson(dueDate),
        "completedAt": dtToJson(completedAt),
        "carried": carried,
        "recurringId": recurringId,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j["id"] as String,
        text: j["text"] as String,
        difficulty: enumByName(Difficulty.values, j["difficulty"] as String?, Difficulty.normal),
        category: enumByName(TaskCategory.values, j["category"] as String?, TaskCategory.other),
        bucket: enumByName(TaskBucket.values, j["bucket"] as String?, TaskBucket.sooner),
        status: enumByName(TaskStatus.values, j["status"] as String?, TaskStatus.pending),
        date: dtFromJson(j["date"]) ?? todayDate(),
        dueDate: dtFromJson(j["dueDate"]),
        completedAt: dtFromJson(j["completedAt"]),
        carried: j["carried"] as bool? ?? false,
        recurringId: j["recurringId"] as String?,
      );
}

// ───────────────────────── projects ─────────────────────────

class ProjectTask {
  String id;
  String text;
  bool done;
  ProjectTask({required this.id, required this.text, this.done = false});

  Map<String, dynamic> toJson() => {"id": id, "text": text, "done": done};
  factory ProjectTask.fromJson(Map<String, dynamic> j) =>
      ProjectTask(id: j["id"] as String, text: j["text"] as String, done: j["done"] as bool? ?? false);
}

class ProjectItem {
  String id;
  String name;
  String desc;
  int colorValue;
  List<ProjectTask> tasks;
  DateTime createdAt;

  ProjectItem({
    required this.id,
    required this.name,
    this.desc = "",
    required this.colorValue,
    List<ProjectTask>? tasks,
    required this.createdAt,
  }) : tasks = tasks ?? [];

  int get doneCount => tasks.where((t) => t.done).length;
  double get progress => tasks.isEmpty ? 0 : doneCount / tasks.length;

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "desc": desc,
        "color": colorValue,
        "tasks": tasks.map((t) => t.toJson()).toList(),
        "createdAt": dtToJson(createdAt),
      };

  factory ProjectItem.fromJson(Map<String, dynamic> j) => ProjectItem(
        id: j["id"] as String,
        name: j["name"] as String,
        desc: j["desc"] as String? ?? "",
        colorValue: j["color"] as int,
        tasks: (j["tasks"] as List? ?? [])
            .map((e) => ProjectTask.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        createdAt: dtFromJson(j["createdAt"]) ?? todayDate(),
      );
}

// ───────────────────────── habits ─────────────────────────

class HabitItem {
  String id;
  String name;
  DateTime startDate;
  Map<String, bool> log; // ymdKey -> ticked
  bool reviewed;

  HabitItem({
    required this.id,
    required this.name,
    required this.startDate,
    Map<String, bool>? log,
    this.reviewed = false,
  }) : log = log ?? {};

  int get streak {
    var s = 0;
    var d = todayDate();
    while (log[ymdKey(d)] == true) {
      s++;
      d = addDays(d, -1);
    }
    return s;
  }

  int get completionPct {
    final elapsed = (daysBetween(startDate, todayDate()) + 1).clamp(0, 30);
    if (elapsed <= 0) return 0;
    var done = 0;
    for (var i = 0; i < elapsed; i++) {
      if (log[ymdKey(addDays(startDate, i))] == true) done++;
    }
    return ((done / elapsed) * 100).round();
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "startDate": dtToJson(startDate),
        "log": log,
        "reviewed": reviewed,
      };

  factory HabitItem.fromJson(Map<String, dynamic> j) => HabitItem(
        id: j["id"] as String,
        name: j["name"] as String,
        startDate: dtFromJson(j["startDate"]) ?? todayDate(),
        log: (j["log"] as Map? ?? {}).map((k, v) => MapEntry(k as String, v as bool)),
        reviewed: j["reviewed"] as bool? ?? false,
      );
}

// ───────────────────────── events / calendar ─────────────────────────

class EventItem {
  String id;
  String title;
  DateTime date;
  int? hour;
  int? minute;
  EventPriority priority;
  bool reminder;
  int reminderMinutes;
  bool done;

  EventItem({
    required this.id,
    required this.title,
    required this.date,
    this.hour,
    this.minute,
    this.priority = EventPriority.normal,
    this.reminder = false,
    this.reminderMinutes = 60,
    this.done = false,
  });

  bool get hasTime => hour != null && minute != null;
  String get timeText => hasTime ? timeLabel(hour!, minute!) : "";

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "date": dtToJson(date),
        "hour": hour,
        "minute": minute,
        "priority": priority.name,
        "reminder": reminder,
        "reminderMinutes": reminderMinutes,
        "done": done,
      };

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
        id: j["id"] as String,
        title: j["title"] as String,
        date: dtFromJson(j["date"]) ?? todayDate(),
        hour: j["hour"] as int?,
        minute: j["minute"] as int?,
        priority: enumByName(EventPriority.values, j["priority"] as String?, EventPriority.normal),
        reminder: j["reminder"] as bool? ?? false,
        reminderMinutes: j["reminderMinutes"] as int? ?? 60,
        done: j["done"] as bool? ?? false,
      );
}

// ───────────────────────── goals ─────────────────────────

class GoalItem {
  String id;
  String text;
  bool done;
  bool carried;
  GoalItem({required this.id, required this.text, this.done = false, this.carried = false});

  Map<String, dynamic> toJson() => {"id": id, "text": text, "done": done, "carried": carried};
  factory GoalItem.fromJson(Map<String, dynamic> j) => GoalItem(
        id: j["id"] as String,
        text: j["text"] as String,
        done: j["done"] as bool? ?? false,
        carried: j["carried"] as bool? ?? false,
      );
}

class GoalSnapshot {
  String text;
  bool done;
  GoalSnapshot({required this.text, required this.done});
  Map<String, dynamic> toJson() => {"text": text, "done": done};
  factory GoalSnapshot.fromJson(Map<String, dynamic> j) =>
      GoalSnapshot(text: j["text"] as String, done: j["done"] as bool? ?? false);
}

class GoalHistoryEntry {
  String label;
  List<GoalSnapshot> goals;
  GoalHistoryEntry({required this.label, required this.goals});

  Map<String, dynamic> toJson() => {"label": label, "goals": goals.map((g) => g.toJson()).toList()};
  factory GoalHistoryEntry.fromJson(Map<String, dynamic> j) => GoalHistoryEntry(
        label: j["label"] as String,
        goals: (j["goals"] as List? ?? [])
            .map((e) => GoalSnapshot.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

// ───────────────────────── daily review ─────────────────────────

class DailyReview {
  DateTime date;
  ReviewMood mood;
  String note;
  DailyReview({required this.date, required this.mood, this.note = ""});

  Map<String, dynamic> toJson() => {"date": dtToJson(date), "mood": mood.name, "note": note};
  factory DailyReview.fromJson(Map<String, dynamic> j) => DailyReview(
        date: dtFromJson(j["date"]) ?? todayDate(),
        mood: enumByName(ReviewMood.values, j["mood"] as String?, ReviewMood.okay),
        note: j["note"] as String? ?? "",
      );
}

// ───────────────────────── notifications ─────────────────────────

class AppNotificationItem {
  String id;
  String title;
  String body;
  DateTime time;
  bool read;
  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  Map<String, dynamic> toJson() =>
      {"id": id, "title": title, "body": body, "time": dtToJson(time), "read": read};
  factory AppNotificationItem.fromJson(Map<String, dynamic> j) => AppNotificationItem(
        id: j["id"] as String,
        title: j["title"] as String,
        body: j["body"] as String,
        time: dtFromJson(j["time"]) ?? DateTime.now(),
        read: j["read"] as bool? ?? false,
      );
}
