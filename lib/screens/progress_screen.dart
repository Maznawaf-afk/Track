import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final stats = appState.computeWeekStats();
    final maxCategoryCount =
        stats.categoryCounts.values.isEmpty ? 0 : stats.categoryCounts.values.reduce((a, b) => a > b ? a : b);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text("INSIGHTS",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.muted)),
          const SizedBox(height: 4),
          const Text("Progress", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          const Text("This week", style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _statTile("Completed", "${stats.completed}", "tasks", AppColors.greenDark),
              _statTile("Best day", stats.bestDay ?? "—", "", AppColors.accentDark),
              _statTile("Average", stats.avgPerDay.toStringAsFixed(1), "tasks / day", AppColors.blueDark),
              _statTile(
                "Top category",
                stats.topCategory == null ? "—" : "${stats.topCategory!.emoji} ${stats.topCategory!.label}",
                "",
                AppColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Completed by category", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text("Last 7 days", style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 14),
                if (stats.categoryCounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text("Complete a few tasks this week to see a breakdown.",
                        style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
                  )
                else
                  ...TaskCategory.values
                      .where((c) => (stats.categoryCounts[c] ?? 0) > 0)
                      .toList()
                      .map((c) => _categoryBar(c, stats.categoryCounts[c] ?? 0, maxCategoryCount)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.whatshot, color: AppColors.brick),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stats.completed == 0
                        ? "No tasks completed yet this week — Today's priorities are a good place to start."
                        : "You finished ${stats.completed} task${stats.completed == 1 ? '' : 's'} this week"
                            "${stats.bestDay != null ? ', with ${stats.bestDay} being your strongest day.' : '.'}",
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          if (unit.isNotEmpty)
            Text(unit, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _categoryBar(TaskCategory c, int count, int max) {
    final frac = max == 0 ? 0.0 : count / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${c.emoji} ${c.label}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text("$count", style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 7,
              backgroundColor: AppColors.surface2,
              valueColor: const AlwaysStoppedAnimation(AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
