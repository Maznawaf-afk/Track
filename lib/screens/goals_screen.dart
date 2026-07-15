import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String _tab = "week";
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final isWeek = _tab == "week";

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text("FOCUS",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.muted)),
          const SizedBox(height: 4),
          const Text("Goals", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: _tabButton("This week", "week")),
                Expanded(child: _tabButton("This month", "month")),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (isWeek) _weekSection(appState) else _monthSection(appState),
          if (!isWeek) ...[
            const SizedBox(height: 8),
            _remindersCard(appState),
            const SizedBox(height: 16),
            _backupCard(context, appState),
            const SizedBox(height: 20),
            const Center(
              child: Text("Your data stays on this device unless you export a backup.",
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted), textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(String label, String value) {
    final on = _tab == value;
    return GestureDetector(
      onTap: () => setState(() => _tab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: on ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? AppColors.text : AppColors.muted)),
      ),
    );
  }

  Widget _weekSection(AppState appState) {
    final done = appState.weekGoals.where((g) => g.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (appState.weekDue) _reviewBanner("Your 7 days are up", "Tick what you finished, then start a fresh week. Anything unticked carries over.", "Carry unfinished & start new week", appState.finishWeek),
        _addRow(() {
          final t = _addCtrl.text.trim();
          if (t.isEmpty) return;
          appState.addWeekGoal(t);
          _addCtrl.clear();
        }, "Add a goal for this week…"),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("GOALS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            Text("$done done", style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        if (appState.weekGoals.isEmpty)
          emptyState("No goals yet. Add what you want to get done this week.")
        else
          ...appState.weekGoals.map((g) => _goalTile(g, () => appState.toggleWeekGoal(g.id), () => appState.deleteWeekGoal(g.id))),
        const SizedBox(height: 16),
        _historySection("Past weeks", appState.weekHistory, appState.clearWeekHistory),
      ],
    );
  }

  Widget _monthSection(AppState appState) {
    final done = appState.monthGoals.where((g) => g.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (appState.monthDue) _reviewBanner("A new month is here", "Tick what you finished last month, then set this month's targets. Anything unticked carries over.", "Carry unfinished & start new month", appState.finishMonth),
        _addRow(() {
          final t = _addCtrl.text.trim();
          if (t.isEmpty) return;
          appState.addMonthGoal(t);
          _addCtrl.clear();
        }, "Add a target for this month…"),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("TARGETS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            Text("$done done", style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        if (appState.monthGoals.isEmpty)
          emptyState("No targets yet. Add what you want to achieve this month.")
        else
          ...appState.monthGoals.map((g) => _goalTile(g, () => appState.toggleMonthGoal(g.id), () => appState.deleteMonthGoal(g.id))),
        const SizedBox(height: 16),
        _historySection("Past months", appState.monthHistory, appState.clearMonthHistory),
      ],
    );
  }

  Widget _reviewBanner(String title, String message, String actionLabel, Future<void> Function() onAction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.green.withOpacity(0.16), AppColors.green.withOpacity(0.05)]),
        border: Border.all(color: AppColors.green),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
          const SizedBox(height: 5),
          Text(message, style: const TextStyle(fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: () => onAction(),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRow(VoidCallback onAdd, String hint) {
    return Row(
      children: [
        Expanded(child: TextField(controller: _addCtrl, decoration: InputDecoration(hintText: hint), onSubmitted: (_) => onAdd())),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: onAdd, child: const Icon(Icons.add)),
      ],
    );
  }

  Widget _goalTile(GoalItem g, VoidCallback onToggle, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Dismissible(
          key: ValueKey("goal-${g.id}"),
          background: Container(
              color: AppColors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 18), child: const Text("✓ Done", style: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800))),
          secondaryBackground: Container(
              color: AppColors.brick, alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 18), child: const Text("Delete", style: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800))),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              if (!g.done) onToggle();
              return false;
            }
            return true;
          },
          onDismissed: (_) => onDelete(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: g.done ? AppColors.green : AppColors.field,
                      border: Border.all(color: g.done ? AppColors.green : AppColors.line, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: g.done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(g.text,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: g.done ? AppColors.muted : AppColors.text,
                          decoration: g.done ? TextDecoration.lineThrough : null)),
                ),
                if (g.carried) const Text("↻", style: TextStyle(color: AppColors.accentDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historySection(String label, List<GoalHistoryEntry> history, Future<void> Function() onClear) {
    if (history.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.6)),
        children: [
          ...history.take(12).map((h) {
            final done = h.goals.where((g) => g.done).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text("$done of ${h.goals.length} finished", style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  const SizedBox(height: 5),
                  ...h.goals.map((g) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Text(g.done ? "✓" : "○", style: TextStyle(color: g.done ? AppColors.greenDark : AppColors.brick, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(g.text, style: const TextStyle(fontSize: 13.5, color: AppColors.muted))),
                        ]),
                      )),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                final ok = await confirmDialog(context, title: "Clear history?", message: "This removes all past $label entries.", confirmLabel: "Clear", danger: true);
                if (ok) await onClear();
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.brick),
              child: const Text("Clear history"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remindersCard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Reminders", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(appState.remindersOn ? "On — morning 8am & evening 6pm." : "Morning & evening nudges, plus event alerts.",
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(value: appState.remindersOn, activeColor: AppColors.green, onChanged: (v) => appState.setRemindersOn(v)),
        ],
      ),
    );
  }

  Widget _backupCard(BuildContext context, AppState appState) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Backup your data", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text("Everything lives only on this device. Export a backup before switching phones or clearing app data.",
              style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _showExportDialog(context, appState), child: const Text("Export"))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(onPressed: () => _showImportDialog(context, appState), child: const Text("Import"))),
            ],
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, AppState appState) {
    final json = appState.exportJson();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Export backup"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(json, style: const TextStyle(fontSize: 11, fontFamily: "monospace")),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              showToast(context, "Copied — paste it into a .json file to save it.");
            },
            child: const Text("Copy to clipboard"),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, AppState appState) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Import backup"),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            decoration: const InputDecoration(hintText: "Paste your exported backup JSON here…"),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final confirmed = await confirmDialog(ctx,
                  title: "Overwrite current data?",
                  message: "Importing replaces everything currently in the app with this backup.",
                  confirmLabel: "Import",
                  danger: true);
              if (!confirmed) return;
              try {
                await appState.importJson(ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) showToast(context, "Backup imported.");
              } catch (e) {
                if (context.mounted) showToast(context, "Couldn't import — that doesn't look like a valid backup.");
              }
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }
}
