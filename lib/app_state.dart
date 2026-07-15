import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'date_utils.dart';
import 'models.dart';
import 'notification_service.dart';

String newId() {
  final r = Random();
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      r.nextInt(1 << 32).toRadixString(36);
}

enum TaskTextProblem { ok, tooShort, noLetterOrDigit, duplicate }

class WeekStats {
  final int completed;
  final String? bestDay;
  final double avgPerDay;
  final TaskCategory? topCategory;
  final Map<TaskCategory, int> categoryCounts;
  const WeekStats({
    required this.completed,
    required this.bestDay,
    required this.avgPerDay,
    required this.topCategory,
    required this.categoryCounts,
  });
}

/// Holds every piece of app data, persists it to [SharedPreferences], and
/// implements all the cross-cutting daily/weekly/monthly logic (rollover,
/// recurring-task generation, stats). Screens read from this via
/// [AnimatedBuilder]/`ListenableBuilder` and call its mutating methods,
/// which always call [notifyListeners] after saving.
class AppState extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool ready = false;

  // Onboarding / settings
  bool onboarded = false;
  String userName = "";
  List<String> mainGoals = [];
  int dailyLimit = 5;
  FocusStyle focusStyle = FocusStyle.balanced;
  bool remindersOn = false;

  // Collections
  List<TaskItem> tasks = [];
  List<RecurringTemplate> recurring = [];
  List<ProjectItem> projects = [];
  List<HabitItem> habits = [];
  List<EventItem> events = [];

  List<GoalItem> weekGoals = [];
  DateTime? weekStart;
  List<GoalHistoryEntry> weekHistory = [];

  List<GoalItem> monthGoals = [];
  String? monthKey;
  List<GoalHistoryEntry> monthHistory = [];

  List<AppNotificationItem> notifications = [];
  Map<String, DailyReview> dailyReviews = {}; // key: ymdKey

  final NotificationService notifier = NotificationService();

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;

    onboarded = p.getBool("onboarded") ?? false;
    userName = p.getString("userName") ?? "";
    mainGoals = p.getStringList("mainGoals") ?? [];
    dailyLimit = p.getInt("dailyLimit") ?? 5;
    focusStyle = enumByName(FocusStyle.values, p.getString("focusStyle"), FocusStyle.balanced);
    remindersOn = p.getBool("remindersOn") ?? false;

    tasks = _loadList(p, "tasks", TaskItem.fromJson);
    recurring = _loadList(p, "recurring", RecurringTemplate.fromJson);
    projects = _loadList(p, "projects", ProjectItem.fromJson);
    habits = _loadList(p, "habits", HabitItem.fromJson);
    events = _loadList(p, "events", EventItem.fromJson);

    weekGoals = _loadList(p, "weekGoals", GoalItem.fromJson);
    final ws = p.getString("weekStart");
    weekStart = ws == null ? null : DateTime.parse(ws);
    weekHistory = _loadList(p, "weekHistory", GoalHistoryEntry.fromJson);

    monthGoals = _loadList(p, "monthGoals", GoalItem.fromJson);
    monthKey = p.getString("monthKey");
    monthHistory = _loadList(p, "monthHistory", GoalHistoryEntry.fromJson);

    notifications = _loadList(p, "notifications", AppNotificationItem.fromJson);

    final reviewsRaw = p.getString("dailyReviews");
    dailyReviews = {};
    if (reviewsRaw != null) {
      try {
        final decoded = jsonDecode(reviewsRaw) as Map;
        decoded.forEach((k, v) {
          dailyReviews[k as String] = DailyReview.fromJson((v as Map).cast<String, dynamic>());
        });
      } catch (_) {}
    }

    await notifier.init();

    ensureCycles();
    rolloverDaily();
    ensureRecurringInstances();

    ready = true;
    notifyListeners();
    if (remindersOn) {
      await notifier.scheduleDailyReminders();
      await notifier.scheduleEventReminders(events);
    }
  }

  // ── generic list persistence ──

  List<T> _loadList<T>(SharedPreferences p, String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = p.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => fromJson((e as Map).cast<String, dynamic>())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveList(String key, List list) async {
    final encoded = jsonEncode(list.map((e) => (e as dynamic).toJson()).toList());
    await _prefs?.setString(key, encoded);
  }

  Future<void> saveTasks() => _saveList("tasks", tasks);
  Future<void> saveRecurring() => _saveList("recurring", recurring);
  Future<void> saveProjects() => _saveList("projects", projects);
  Future<void> saveHabits() => _saveList("habits", habits);
  Future<void> saveEvents() => _saveList("events", events);
  Future<void> saveNotifications() => _saveList("notifications", notifications);

  Future<void> saveWeek() async {
    await _saveList("weekGoals", weekGoals);
    if (weekStart != null) await _prefs?.setString("weekStart", weekStart!.toIso8601String());
    await _saveList("weekHistory", weekHistory);
  }

  Future<void> saveMonth() async {
    await _saveList("monthGoals", monthGoals);
    if (monthKey != null) await _prefs?.setString("monthKey", monthKey!);
    await _saveList("monthHistory", monthHistory);
  }

  Future<void> saveDailyReviews() async {
    final encoded = jsonEncode(dailyReviews.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString("dailyReviews", encoded);
  }

  Future<void> saveSettings() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool("onboarded", onboarded);
    await p.setString("userName", userName);
    await p.setStringList("mainGoals", mainGoals);
    await p.setInt("dailyLimit", dailyLimit);
    await p.setString("focusStyle", focusStyle.name);
    await p.setBool("remindersOn", remindersOn);
  }

  // ── onboarding ──

  Future<void> completeOnboarding({
    required String name,
    required List<String> goals,
    required int limit,
    required FocusStyle style,
  }) async {
    userName = name;
    mainGoals = goals;
    dailyLimit = limit;
    focusStyle = style;
    onboarded = true;
    await saveSettings();
    notifyListeners();
  }

  // ── daily rollover / cycle bookkeeping ──

  void ensureCycles() {
    weekStart ??= todayDate();
    monthKey ??= monthKeyOf(todayDate());
  }

  void rolloverDaily() {
    final t = todayDate();
    var changed = false;
    for (final x in tasks) {
      if (x.status != TaskStatus.done && x.date.isBefore(t)) {
        x.date = t;
        x.carried = true;
        changed = true;
      }
    }
    if (changed) saveTasks();
  }

  void ensureRecurringInstances() {
    final t = todayDate();
    var changed = false;
    for (final tpl in recurring) {
      if (!tpl.rule.matches(t)) continue;
      final exists = tasks.any((x) => x.recurringId == tpl.id && isSameDay(x.date, t));
      if (exists) continue;
      tasks.add(TaskItem(
        id: newId(),
        text: tpl.text,
        difficulty: tpl.difficulty,
        category: tpl.category,
        bucket: tpl.bucket,
        status: TaskStatus.pending,
        date: t,
        recurringId: tpl.id,
      ));
      changed = true;
    }
    if (changed) saveTasks();
  }

  /// Call when the app returns to the foreground so a day-change is picked
  /// up without requiring a full restart.
  void onResume() {
    ensureCycles();
    rolloverDaily();
    ensureRecurringInstances();
    notifyListeners();
  }

  bool get weekDue => weekStart != null && daysBetween(weekStart!, todayDate()) >= 7;
  bool get monthDue => monthKey != null && monthKey != monthKeyOf(todayDate());

  Future<void> finishWeek() async {
    weekHistory.insert(
      0,
      GoalHistoryEntry(
        label: "${prettyDate(weekStart!)} – ${prettyDate(todayDate())}",
        goals: weekGoals.map((g) => GoalSnapshot(text: g.text, done: g.done)).toList(),
      ),
    );
    if (weekHistory.length > 30) weekHistory = weekHistory.sublist(0, 30);
    weekGoals = weekGoals.where((g) => !g.done).map((g) {
      g.carried = true;
      return g;
    }).toList();
    weekStart = todayDate();
    await saveWeek();
    notifyListeners();
  }

  Future<void> finishMonth() async {
    monthHistory.insert(
      0,
      GoalHistoryEntry(
        label: monthLabelOf(monthKey!),
        goals: monthGoals.map((g) => GoalSnapshot(text: g.text, done: g.done)).toList(),
      ),
    );
    if (monthHistory.length > 30) monthHistory = monthHistory.sublist(0, 30);
    monthGoals = monthGoals.where((g) => !g.done).map((g) {
      g.carried = true;
      return g;
    }).toList();
    monthKey = monthKeyOf(todayDate());
    await saveMonth();
    notifyListeners();
  }

  Future<void> clearWeekHistory() async {
    weekHistory = [];
    await saveWeek();
    notifyListeners();
  }

  Future<void> clearMonthHistory() async {
    monthHistory = [];
    await saveMonth();
    notifyListeners();
  }

  // ── in-app notifications ──

  Future<void> pushInApp(String title, String body) async {
    notifications.insert(0, AppNotificationItem(id: newId(), title: title, body: body, time: DateTime.now()));
    if (notifications.length > 40) notifications = notifications.sublist(0, 40);
    await saveNotifications();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    for (final n in notifications) {
      n.read = true;
    }
    await saveNotifications();
    notifyListeners();
  }

  int get unreadNotificationCount => notifications.where((n) => !n.read).length;

  Future<void> setRemindersOn(bool on) async {
    remindersOn = on;
    await saveSettings();
    if (on) {
      final granted = await notifier.requestPermission();
      if (granted) {
        await notifier.scheduleDailyReminders();
        await notifier.scheduleEventReminders(events);
        await pushInApp("Reminders on", "You'll get morning & evening nudges.");
      } else {
        remindersOn = false;
        await saveSettings();
      }
    } else {
      await notifier.cancelAll();
    }
    notifyListeners();
  }

  // ── tasks ──

  List<TaskItem> tasksOn(DateTime date) => tasks.where((t) => isSameDay(t.date, date)).toList();

  List<TaskItem> bucketTasksOn(TaskBucket bucket, DateTime date) =>
      tasksOn(date).where((t) => t.bucket == bucket).toList();

  bool isSoonerAtLimit(DateTime date) =>
      bucketTasksOn(TaskBucket.sooner, date).length >= dailyLimit;

  List<TaskItem> sortTasks(List<TaskItem> list) {
    final copy = List<TaskItem>.from(list);
    copy.sort((a, b) {
      final s = a.status.rank.compareTo(b.status.rank);
      if (s != 0) return s;
      final d = a.difficulty.rank.compareTo(b.difficulty.rank);
      if (d != 0) return d;
      return a.id.compareTo(b.id);
    });
    return copy;
  }

  TaskTextProblem validateTaskText(
    String raw, {
    required TaskBucket bucket,
    required DateTime date,
    String? excludeId,
  }) {
    final text = raw.trim();
    if (text.length < 3) return TaskTextProblem.tooShort;
    if (!RegExp(r'[a-zA-Z0-9؀-ۿ]').hasMatch(text)) return TaskTextProblem.noLetterOrDigit;
    final dup = tasksOn(date).any((t) =>
        t.id != excludeId && t.bucket == bucket && t.text.trim().toLowerCase() == text.toLowerCase());
    if (dup) return TaskTextProblem.duplicate;
    return TaskTextProblem.ok;
  }

  Future<TaskItem> addTask({
    required String text,
    required Difficulty difficulty,
    required TaskCategory category,
    required TaskBucket bucket,
    DateTime? dueDate,
  }) async {
    final t = TaskItem(
      id: newId(),
      text: text.trim(),
      difficulty: difficulty,
      category: category,
      bucket: bucket,
      status: TaskStatus.pending,
      date: todayDate(),
      dueDate: dueDate,
    );
    tasks.add(t);
    await saveTasks();
    notifyListeners();
    return t;
  }

  Future<void> updateTask(
    String id, {
    String? text,
    Difficulty? difficulty,
    TaskCategory? category,
    TaskBucket? bucket,
    Object? dueDate = _unset,
  }) async {
    final t = tasks.firstWhere((x) => x.id == id);
    if (text != null) t.text = text.trim();
    if (difficulty != null) t.difficulty = difficulty;
    if (category != null) t.category = category;
    if (bucket != null) t.bucket = bucket;
    if (!identical(dueDate, _unset)) t.dueDate = dueDate as DateTime?;
    await saveTasks();
    notifyListeners();
  }

  Future<void> cycleStatus(String id) async {
    final t = tasks.firstWhere((x) => x.id == id);
    t.status = t.status == TaskStatus.pending
        ? TaskStatus.working
        : (t.status == TaskStatus.working ? TaskStatus.done : TaskStatus.pending);
    t.completedAt = t.status == TaskStatus.done ? DateTime.now() : null;
    await saveTasks();
    notifyListeners();
  }

  Future<void> setStatus(String id, TaskStatus status) async {
    final t = tasks.firstWhere((x) => x.id == id);
    t.status = status;
    t.completedAt = status == TaskStatus.done ? DateTime.now() : null;
    await saveTasks();
    notifyListeners();
  }

  Future<void> moveBucket(String id) async {
    final t = tasks.firstWhere((x) => x.id == id);
    t.bucket = t.bucket == TaskBucket.sooner ? TaskBucket.later : TaskBucket.sooner;
    await saveTasks();
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    tasks.removeWhere((x) => x.id == id);
    await saveTasks();
    notifyListeners();
  }

  Future<void> moveAllRemainingToTomorrow() async {
    final tomorrow = addDays(todayDate(), 1);
    for (final t in tasksOn(todayDate())) {
      if (t.status != TaskStatus.done) {
        t.date = tomorrow;
        t.carried = true;
      }
    }
    await saveTasks();
    await pushInApp("Tasks moved", "Remaining tasks moved to tomorrow.");
    notifyListeners();
  }

  // ── recurring templates ──

  Future<void> addRecurring(RecurringTemplate tpl) async {
    recurring.add(tpl);
    await saveRecurring();
    ensureRecurringInstances();
    notifyListeners();
  }

  Future<void> deleteRecurring(String id) async {
    recurring.removeWhere((x) => x.id == id);
    await saveRecurring();
    notifyListeners();
  }

  // ── projects ──

  Future<void> addProject(String name, String desc, int color) async {
    projects.add(ProjectItem(id: newId(), name: name, desc: desc, colorValue: color, createdAt: todayDate()));
    await saveProjects();
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    projects.removeWhere((x) => x.id == id);
    await saveProjects();
    notifyListeners();
  }

  Future<void> addProjectTask(String projectId, String text) async {
    final proj = projects.firstWhere((x) => x.id == projectId);
    proj.tasks.add(ProjectTask(id: newId(), text: text));
    await saveProjects();
    notifyListeners();
  }

  Future<void> toggleProjectTask(String projectId, String taskId) async {
    final proj = projects.firstWhere((x) => x.id == projectId);
    final t = proj.tasks.firstWhere((x) => x.id == taskId);
    t.done = !t.done;
    await saveProjects();
    notifyListeners();
  }

  Future<void> deleteProjectTask(String projectId, String taskId) async {
    final proj = projects.firstWhere((x) => x.id == projectId);
    proj.tasks.removeWhere((x) => x.id == taskId);
    await saveProjects();
    notifyListeners();
  }

  // ── habits ──

  Future<void> addHabit(String name) async {
    habits.add(HabitItem(id: newId(), name: name, startDate: todayDate()));
    await saveHabits();
    notifyListeners();
  }

  Future<void> deleteHabit(String id) async {
    habits.removeWhere((x) => x.id == id);
    await saveHabits();
    notifyListeners();
  }

  Future<void> toggleHabitToday(String id) async {
    final h = habits.firstWhere((x) => x.id == id);
    final k = ymdKey(todayDate());
    h.log[k] = !(h.log[k] ?? false);
    await saveHabits();
    notifyListeners();
  }

  Future<void> continueHabit(String id) async {
    final h = habits.firstWhere((x) => x.id == id);
    h.startDate = todayDate();
    h.log = {};
    h.reviewed = false;
    await saveHabits();
    notifyListeners();
  }

  Future<void> archiveHabit(String id) async {
    final h = habits.firstWhere((x) => x.id == id);
    h.reviewed = true;
    await saveHabits();
    notifyListeners();
  }

  // ── events ──

  Future<void> addEvent(EventItem ev) async {
    events.add(ev);
    await saveEvents();
    if (remindersOn) await notifier.scheduleEventReminders(events);
    notifyListeners();
  }

  Future<void> toggleEventDone(String id) async {
    final e = events.firstWhere((x) => x.id == id);
    e.done = !e.done;
    await saveEvents();
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    events.removeWhere((x) => x.id == id);
    await saveEvents();
    if (remindersOn) await notifier.scheduleEventReminders(events);
    notifyListeners();
  }

  List<EventItem> eventsOn(DateTime date) => events.where((e) => isSameDay(e.date, date)).toList();

  // ── goals ──

  Future<void> addWeekGoal(String text) async {
    weekGoals.add(GoalItem(id: newId(), text: text));
    await saveWeek();
    notifyListeners();
  }

  Future<void> toggleWeekGoal(String id) async {
    final g = weekGoals.firstWhere((x) => x.id == id);
    g.done = !g.done;
    await saveWeek();
    notifyListeners();
  }

  Future<void> deleteWeekGoal(String id) async {
    weekGoals.removeWhere((x) => x.id == id);
    await saveWeek();
    notifyListeners();
  }

  Future<void> addMonthGoal(String text) async {
    monthGoals.add(GoalItem(id: newId(), text: text));
    await saveMonth();
    notifyListeners();
  }

  Future<void> toggleMonthGoal(String id) async {
    final g = monthGoals.firstWhere((x) => x.id == id);
    g.done = !g.done;
    await saveMonth();
    notifyListeners();
  }

  Future<void> deleteMonthGoal(String id) async {
    monthGoals.removeWhere((x) => x.id == id);
    await saveMonth();
    notifyListeners();
  }

  // ── daily review ──

  bool get reviewedToday => dailyReviews.containsKey(ymdKey(todayDate()));

  Future<void> saveTodayReview(ReviewMood mood, String note) async {
    dailyReviews[ymdKey(todayDate())] = DailyReview(date: todayDate(), mood: mood, note: note);
    await saveDailyReviews();
    notifyListeners();
  }

  // ── statistics (Progress page) ──

  WeekStats computeWeekStats() {
    final t = todayDate();
    final start = addDays(t, -6);
    final completed = tasks.where((x) =>
        x.status == TaskStatus.done && x.completedAt != null && !dateOnly(x.completedAt!).isBefore(start) && !dateOnly(x.completedAt!).isAfter(t));

    final perDay = <String, int>{};
    final perCategory = <TaskCategory, int>{};
    for (final x in completed) {
      final k = ymdKey(dateOnly(x.completedAt!));
      perDay[k] = (perDay[k] ?? 0) + 1;
      perCategory[x.category] = (perCategory[x.category] ?? 0) + 1;
    }
    String? bestDay;
    var bestCount = 0;
    perDay.forEach((k, v) {
      if (v > bestCount) {
        bestCount = v;
        bestDay = k;
      }
    });
    TaskCategory? topCategory;
    var topCount = 0;
    perCategory.forEach((k, v) {
      if (v > topCount) {
        topCount = v;
        topCategory = k;
      }
    });
    final totalCompleted = completed.length;
    return WeekStats(
      completed: totalCompleted,
      bestDay: bestDay == null ? null : weekdayFullOf(DateTime.parse(bestDay!)),
      avgPerDay: totalCompleted / 7.0,
      topCategory: topCategory,
      categoryCounts: perCategory,
    );
  }

  // ── backup export / import ──

  Map<String, dynamic> exportAll() => {
        "_app": "track",
        "_version": 1,
        "settings": {
          "onboarded": onboarded,
          "userName": userName,
          "mainGoals": mainGoals,
          "dailyLimit": dailyLimit,
          "focusStyle": focusStyle.name,
          "remindersOn": remindersOn,
        },
        "tasks": tasks.map((e) => e.toJson()).toList(),
        "recurring": recurring.map((e) => e.toJson()).toList(),
        "projects": projects.map((e) => e.toJson()).toList(),
        "habits": habits.map((e) => e.toJson()).toList(),
        "events": events.map((e) => e.toJson()).toList(),
        "weekGoals": weekGoals.map((e) => e.toJson()).toList(),
        "weekStart": dtToJson(weekStart),
        "weekHistory": weekHistory.map((e) => e.toJson()).toList(),
        "monthGoals": monthGoals.map((e) => e.toJson()).toList(),
        "monthKey": monthKey,
        "monthHistory": monthHistory.map((e) => e.toJson()).toList(),
        "dailyReviews": dailyReviews.map((k, v) => MapEntry(k, v.toJson())),
      };

  String exportJson() => const JsonEncoder.withIndent("  ").convert(exportAll());

  /// Restores state from a previously exported backup. Throws
  /// [FormatException] on invalid input — callers should catch and show the
  /// error to the user rather than losing existing data silently.
  Future<void> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded["_app"] != "track") {
      throw const FormatException("This doesn't look like a Track backup file.");
    }
    final j = decoded.cast<String, dynamic>();
    final settings = (j["settings"] as Map).cast<String, dynamic>();
    onboarded = settings["onboarded"] as bool? ?? onboarded;
    userName = settings["userName"] as String? ?? userName;
    mainGoals = (settings["mainGoals"] as List? ?? []).cast<String>();
    dailyLimit = settings["dailyLimit"] as int? ?? dailyLimit;
    focusStyle = enumByName(FocusStyle.values, settings["focusStyle"] as String?, focusStyle);
    remindersOn = settings["remindersOn"] as bool? ?? remindersOn;

    tasks = (j["tasks"] as List? ?? []).map((e) => TaskItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    recurring = (j["recurring"] as List? ?? [])
        .map((e) => RecurringTemplate.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    projects = (j["projects"] as List? ?? [])
        .map((e) => ProjectItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    habits =
        (j["habits"] as List? ?? []).map((e) => HabitItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    events =
        (j["events"] as List? ?? []).map((e) => EventItem.fromJson((e as Map).cast<String, dynamic>())).toList();

    weekGoals =
        (j["weekGoals"] as List? ?? []).map((e) => GoalItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    weekStart = dtFromJson(j["weekStart"]);
    weekHistory = (j["weekHistory"] as List? ?? [])
        .map((e) => GoalHistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    monthGoals =
        (j["monthGoals"] as List? ?? []).map((e) => GoalItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    monthKey = j["monthKey"] as String?;
    monthHistory = (j["monthHistory"] as List? ?? [])
        .map((e) => GoalHistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    dailyReviews = {};
    final reviews = (j["dailyReviews"] as Map?)?.cast<String, dynamic>() ?? {};
    reviews.forEach((k, v) {
      dailyReviews[k] = DailyReview.fromJson((v as Map).cast<String, dynamic>());
    });

    ensureCycles();
    rolloverDaily();
    ensureRecurringInstances();

    await saveSettings();
    await saveTasks();
    await saveRecurring();
    await saveProjects();
    await saveHabits();
    await saveEvents();
    await saveWeek();
    await saveMonth();
    await saveDailyReviews();

    notifyListeners();
  }
}

const Object _unset = Object();
