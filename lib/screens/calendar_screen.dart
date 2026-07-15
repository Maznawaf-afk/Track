import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../date_utils.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _viewMonth = DateTime(todayDate().year, todayDate().month);
  DateTime? _selected;

  void _changeMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final today = todayDate();

    List<EventItem> listedEvents;
    String listLabel;
    if (_selected != null) {
      listedEvents = appState.eventsOn(_selected!);
      listLabel = "${prettyDate(_selected!)} — ${listedEvents.length} event${listedEvents.length == 1 ? '' : 's'}";
    } else {
      listedEvents = appState.events.where((e) => !e.date.isBefore(today)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      listLabel = "Upcoming events";
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text("UPCOMING",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.muted)),
          const SizedBox(height: 4),
          const Text("Calendar", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _navCircle(Icons.chevron_left, () => _changeMonth(-1)),
                    Text("${kMonthNames[_viewMonth.month - 1]} ${_viewMonth.year}",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    _navCircle(Icons.chevron_right, () => _changeMonth(1)),
                  ],
                ),
                const SizedBox(height: 12),
                _monthGrid(appState, today),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(listLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
              TextButton(
                onPressed: () => showAppBottomSheet(context, _EventSheet(initialDate: _selected ?? today)),
                child: const Text("+ Add event"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (listedEvents.isEmpty)
            emptyState("No events${_selected != null ? ' on this day' : ''}. Tap + Add event to create one.")
          else
            ...listedEvents.map((ev) => _eventCard(appState, ev)),
        ],
      ),
    );
  }

  Widget _navCircle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppColors.text),
      ),
    );
  }

  Widget _monthGrid(AppState appState, DateTime today) {
    final first = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday-first offset (Sun=0..Sat=6)

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_viewMonth.year, _viewMonth.month, d);
      final dayEvents = appState.eventsOn(date);
      final isToday = isSameDay(date, today);
      final isSelected = _selected != null && isSameDay(date, _selected!);
      cells.add(GestureDetector(
        onTap: () => setState(() => _selected = date),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: isToday ? AppColors.accent : (isSelected ? AppColors.surface2 : null),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$d",
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppColors.onAccent : (dayEvents.isNotEmpty ? AppColors.text : AppColors.muted))),
              if (dayEvents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: dayEvents.take(3).map((e) {
                      return Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                            color: isToday ? AppColors.onAccent : eventPriorityColor(e.priority), shape: BoxShape.circle),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    return Column(
      children: [
        Row(
          children: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.4)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: cells,
        ),
      ],
    );
  }

  Widget _eventCard(AppState appState, EventItem ev) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: eventPriorityColor(ev.priority), width: 4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Opacity(
        opacity: ev.done ? 0.55 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text("${ev.date.day}", style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text(kMonthShort[ev.date.month - 1],
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: ev.done ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (ev.hasTime)
                        Text(ev.timeText, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      pillTag(ev.priority.label.toUpperCase(),
                          fg: eventPriorityColor(ev.priority), bg: eventPriorityColor(ev.priority).withOpacity(0.12)),
                      if (ev.reminder)
                        Text("🔔 ${_remindLabel(ev.reminderMinutes)}",
                            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => appState.toggleEventDone(ev.id),
              icon: Icon(ev.done ? Icons.undo : Icons.check_circle_outline, size: 20, color: AppColors.muted),
            ),
            IconButton(
              onPressed: () => appState.deleteEvent(ev.id),
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  String _remindLabel(int min) {
    if (min <= 0) return "at event";
    if (min < 60) return "${min}min before";
    if (min == 60) return "1hr before";
    if (min == 1440) return "1 day before";
    return "${min}min before";
  }
}

class _EventSheet extends StatefulWidget {
  final DateTime initialDate;
  const _EventSheet({required this.initialDate});

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  final _titleCtrl = TextEditingController();
  late DateTime _date = widget.initialDate;
  TimeOfDay? _time;
  EventPriority _priority = EventPriority.normal;
  int _reminderMinutes = 0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: todayDate().subtract(const Duration(days: 1)),
      lastDate: todayDate().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showToast(context, "Give the event a title.");
      return;
    }
    final appState = AppStateScope.read(context);
    await appState.addEvent(EventItem(
      id: newId(),
      title: title,
      date: _date,
      hour: _time?.hour,
      minute: _time?.minute,
      priority: _priority,
      reminder: _reminderMinutes > 0,
      reminderMinutes: _reminderMinutes,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Add event", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            maxLength: 100,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Event name…", counterText: ""),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(prettyDate(_date)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickTime,
                  child: Text(_time == null ? "Add time" : _time!.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text("PRIORITY",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            children: EventPriority.values.map((p) {
              final on = p == _priority;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: p == EventPriority.values.last ? 0 : 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: on ? eventPriorityColor(p) : AppColors.surface,
                        border: Border.all(color: on ? eventPriorityColor(p) : AppColors.line),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(p.label,
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.muted)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text("REMINDER",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [0, 15, 60, 1440].map((m) {
              final on = m == _reminderMinutes;
              final label = m == 0 ? "None" : (m == 60 ? "1 hour" : (m == 1440 ? "1 day" : "$m min"));
              return GestureDetector(
                onTap: () => setState(() => _reminderMinutes = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: on ? AppColors.blue : AppColors.surface,
                    border: Border.all(color: on ? AppColors.blue : AppColors.line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.muted)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
              const Spacer(),
              ElevatedButton(onPressed: _save, child: const Text("Add event")),
            ],
          ),
        ],
      ),
    );
  }
}
