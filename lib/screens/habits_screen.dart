import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../date_utils.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _habitCtrl = TextEditingController();

  @override
  void dispose() {
    _habitCtrl.dispose();
    super.dispose();
  }

  void _addHabit() {
    final text = _habitCtrl.text.trim();
    if (text.isEmpty) return;
    AppStateScope.read(context).addHabit(text);
    _habitCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final active = appState.habits.where((h) => !h.reviewed).toList();
    final dueReview = appState.habits
        .where((h) => !h.reviewed && (daysBetween(h.startDate, todayDate()) + 1) >= 30)
        .toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text("30-DAY TRACKER",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.muted)),
          const SizedBox(height: 4),
          const Text("Habits", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(active.isEmpty ? "No active habits" : "${active.length} active habit${active.length == 1 ? '' : 's'}",
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 18),
          ...dueReview.map((h) => _reviewCard(appState, h)),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Completion trend", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Text("7-day rolling average per habit", style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 12),
                if (appState.habits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text("Add habits below to see your trend graph.", style: TextStyle(color: AppColors.muted))),
                  )
                else ...[
                  SizedBox(height: 130, width: double.infinity, child: CustomPaint(painter: _HabitTrendPainter(appState.habits))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: List.generate(appState.habits.length, (i) {
                      final h = appState.habits[i];
                      final color = kHabitColors[i % kHabitColors.length];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(h.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Text("${h.completionPct}%", style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today — ${prettyDate(todayDate())}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text("Add your first habit below ↓", style: TextStyle(color: AppColors.muted, fontSize: 14)),
                  )
                else
                  ...List.generate(active.length, (i) => _habitRow(appState, active[i], i)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _habitCtrl,
                        maxLength: 80,
                        decoration: const InputDecoration(hintText: "Add a habit…", counterText: ""),
                        onSubmitted: (_) => _addHabit(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _addHabit, child: const Icon(Icons.add)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(AppState appState, HabitItem h) {
    final pct = h.completionPct;
    final note = pct >= 80 ? "Great consistency! 🎉" : (pct >= 50 ? "Solid effort — keep going." : "Room to grow.");
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.purple.withOpacity(0.12), AppColors.purple.withOpacity(0.05)]),
        border: Border.all(color: AppColors.purple),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("30-day review: ${h.name}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.purple)),
          const SizedBox(height: 5),
          Text("You completed this habit $pct% of days over the last 30 days. $note",
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
                  onPressed: () => appState.continueHabit(h.id),
                  child: const Text("Continue (new 30 days)"),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => appState.archiveHabit(h.id), child: const Text("Archive")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _habitRow(AppState appState, HabitItem h, int i) {
    final color = kHabitColors[i % kHabitColors.length];
    final ticked = h.log[ymdKey(todayDate())] == true;
    final streak = h.streak;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => appState.toggleHabitToday(h.id),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ticked ? color : AppColors.field,
                border: Border.all(color: ticked ? color : AppColors.line, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ticked ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(h.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
          if (streak > 0) ...[
            Text("🔥 $streak", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(width: 10),
          ],
          GestureDetector(
            onTap: () async {
              final ok = await confirmDialog(context,
                  title: "Delete habit?", message: "Delete '${h.name}'?", confirmLabel: "Delete", danger: true);
              if (ok) await appState.deleteHabit(h.id);
            },
            child: const Icon(Icons.close, size: 18, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _HabitTrendPainter extends CustomPainter {
  final List<HabitItem> habits;
  _HabitTrendPainter(this.habits);

  static const double pl = 34, pt = 8, pb = 20, pr = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - pl - pr;
    final h = size.height - pt - pb;
    if (w <= 0 || h <= 0) return;

    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 0.6;

    for (final pct in [0, 25, 50, 75, 100]) {
      final y = pt + h - (pct / 100 * h);
      canvas.drawLine(Offset(pl, y), Offset(pl + w, y), gridPaint);
      _text(canvas, "$pct%", Offset(pl - 5, y - 4), alignRight: true);
    }
    for (final day in [1, 7, 14, 21, 28]) {
      final x = pl + (day - 1) / 29 * w;
      canvas.drawLine(Offset(x, pt), Offset(x, pt + h), gridPaint);
      _text(canvas, "d$day", Offset(x, pt + h + 4), alignCenter: true);
    }

    for (var hi = 0; hi < habits.length; hi++) {
      final habit = habits[hi];
      final color = kHabitColors[hi % kHabitColors.length];
      final elapsed = (daysBetween(habit.startDate, todayDate()) + 1).clamp(0, 30);
      if (elapsed <= 0) continue;
      final denom = (elapsed - 1) > 29 ? (elapsed - 1) : 29;
      final points = <Offset>[];
      for (var i = 0; i < elapsed; i++) {
        final wStart = i - 6 < 0 ? 0 : i - 6;
        var done = 0, total = 0;
        for (var j = wStart; j <= i; j++) {
          total++;
          if (habit.log[ymdKey(addDays(habit.startDate, j))] == true) done++;
        }
        final rate = total > 0 ? done / total : 0.0;
        final x = pl + (denom == 0 ? 0 : i / denom) * w;
        final y = pt + h - (rate * h);
        points.add(Offset(x, y));
      }
      if (points.isEmpty) continue;

      final areaPath = Path()..moveTo(points.first.dx, pt + h);
      for (final p in points) {
        areaPath.lineTo(p.dx, p.dy);
      }
      areaPath.lineTo(points.last.dx, pt + h);
      areaPath.close();
      canvas.drawPath(areaPath, Paint()..color = color.withOpacity(0.12));

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        linePath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(points.last, 3, Paint()..color = color);
    }
  }

  void _text(Canvas canvas, String text, Offset pos, {bool alignRight = false, bool alignCenter = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 8, color: AppColors.muted)),
      textDirection: TextDirection.ltr,
    )..layout();
    Offset drawPos = pos;
    if (alignRight) drawPos = Offset(pos.dx - tp.width, pos.dy);
    if (alignCenter) drawPos = Offset(pos.dx - tp.width / 2, pos.dy);
    tp.paint(canvas, drawPos);
  }

  @override
  bool shouldRepaint(covariant _HabitTrendPainter oldDelegate) => true;
}
