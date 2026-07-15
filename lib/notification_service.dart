import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Thin wrapper around flutter_local_notifications. Everything here is
/// defensive (try/catch, `_ready` guard) so a platform-specific hiccup on
/// one device never takes the rest of the app down with it — reminders are
/// a nice-to-have, not load-bearing.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    "track_reminders",
    "Track reminders",
    channelDescription: "Daily nudges and event reminders from Track",
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  // Reserve id 1001/1002 for the daily nudges and a block starting at 2000
  // for event reminders, so re-scheduling one kind never clobbers the other.
  static const int _morningId = 1001;
  static const int _eveningId = 1002;
  static const int _eventIdBase = 2000;
  static const int _eventIdSlots = 200;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // If the platform timezone lookup fails, tz falls back to UTC —
      // reminders still fire, just possibly shifted from local time.
    }
    try {
      const androidInit = AndroidInitializationSettings("@mipmap/ic_launcher");
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final darwin =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      var granted = true;
      if (android != null) {
        granted = await android.requestNotificationsPermission() ?? true;
      }
      if (darwin != null) {
        granted = await darwin.requestPermissions(alert: true, badge: true, sound: true) ?? granted;
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<void> showNow(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, _details);
    } catch (_) {}
  }

  Future<void> scheduleDailyReminders() async {
    if (!_ready) return;
    await _scheduleDaily(_morningId, 8, 0, "Good morning ☀️",
        "Plan your day — open Track to see today's priorities.");
    await _scheduleDaily(
        _eveningId, 18, 0, "Evening check-in 🌙", "How did today go? Log your daily review in Track.");
  }

  Future<void> _scheduleDaily(int id, int hour, int minute, String title, String body) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        target,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  /// Replaces every scheduled event reminder with the current set from
  /// [events]. Safe to call after any add/edit/delete.
  Future<void> scheduleEventReminders(List<EventItem> events) async {
    if (!_ready) return;
    for (var i = 0; i < _eventIdSlots; i++) {
      try {
        await _plugin.cancel(_eventIdBase + i);
      } catch (_) {}
    }
    final now = tz.TZDateTime.now(tz.local);
    var idx = 0;
    for (final ev in events) {
      if (idx >= _eventIdSlots) break;
      if (ev.done || !ev.reminder) continue;
      final hour = ev.hour ?? 9;
      final minute = ev.minute ?? 0;
      final fireAt = tz.TZDateTime(tz.local, ev.date.year, ev.date.month, ev.date.day, hour, minute)
          .subtract(Duration(minutes: ev.reminderMinutes));
      if (fireAt.isBefore(now)) continue;
      try {
        await _plugin.zonedSchedule(
          _eventIdBase + idx,
          "Reminder: ${ev.title}",
          ev.hasTime ? "At ${ev.timeText}" : "Today",
          fireAt,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
      idx++;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
