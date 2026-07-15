import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../date_utils.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/task_sheet.dart';
import '../widgets/task_tile.dart';
import 'focus_screen.dart';

/// The redesigned Today page: a single clear answer to "what do I need to
/// do now" up top (hero + Start Focus), a numbered priorities list, and
/// everything lower-priority (Later, completed items, review) pushed below.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final now = DateTime.now();
    final today = todayDate();

    final soonerAll = appState.bucketTasksOn(TaskBucket.sooner, today);
    final soonerActive = appState.sortTasks(soonerAll.where((t) => t.status != TaskStatus.done).toList());
    final soonerDone = soonerAll.where((t) => t.status == TaskStatus.done).toList();
    final laterTasks = appState.sortTasks(appState.bucketTasksOn(TaskBucket.later, today));

    final allToday = appState.tasksOn(today);
    final doneCount = allToday.where((t) => t.status == TaskStatus.done).length;
    final workingCount = allToday.where((t) => t.status == TaskStatus.working).length;
    final pendingCount = allToday.where((t) => t.status == TaskStatus.pending).length;
    final leftCount = workingCount + pendingCount;

    final eveningActionsVisible = now.hour >= 17;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _header(context, appState, now),
          const SizedBox(height: 16),
          _heroCard(context, leftCount, doneCount, workingCount, pendingCount, allToday.length),
          const SizedBox(height: 22),
          _prioritiesHeader(context, appState, soonerAll.length),
          const SizedBox(height: 11),
          if (soonerActive.isEmpty)
            emptyState("Nothing here yet — add your top priority for today.")
          else
            ...List.generate(soonerActive.length, (i) {
              final t = soonerActive[i];
              return FadeSlideIn(
                key: ValueKey(t.id),
                child: TaskTile(
                  task: t,
                  number: i + 1,
                  onTapStatus: () => appState.cycleStatus(t.id),
                  onToggleBucket: () => appState.moveBucket(t.id),
                  onEdit: () => showAppBottomSheet(context, TaskSheet(existing: t)),
                  onComplete: () => appState.setStatus(t.id, TaskStatus.done),
                  onDelete: () => appState.deleteTask(t.id),
                ),
              );
            }),
          if (soonerDone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text("Completed today (${soonerDone.length})",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
                children: soonerDone
                    .map((t) => TaskTile(
                          task: t,
                          allowCompleteSwipe: false,
                          onTapStatus: () => appState.cycleStatus(t.id),
                          onToggleBucket: () => appState.moveBucket(t.id),
                          onEdit: () => showAppBottomSheet(context, TaskSheet(existing: t)),
                          onComplete: () {},
                          onDelete: () => appState.deleteTask(t.id),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 26),
          _laterHeader(context, laterTasks.length),
          const SizedBox(height: 11),
          if (laterTasks.isEmpty)
            emptyState("Nothing later yet.")
          else
            ...laterTasks.map((t) => FadeSlideIn(
                  key: ValueKey(t.id),
                  child: TaskTile(
                    task: t,
                    onTapStatus: () => appState.cycleStatus(t.id),
                    onToggleBucket: () => appState.moveBucket(t.id),
                    onEdit: () => showAppBottomSheet(context, TaskSheet(existing: t)),
                    onComplete: () => appState.setStatus(t.id, TaskStatus.done),
                    onDelete: () => appState.deleteTask(t.id),
                  ),
                )),
          if (eveningActionsVisible) ...[
            const SizedBox(height: 22),
            if (!appState.reviewedToday) const _DailyReviewCard(),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: "Move remaining to tomorrow?",
                      message: "Everything not done today will roll over to tomorrow's Sooner list.",
                      confirmLabel: "Move");
                  if (ok) await appState.moveAllRemainingToTomorrow();
                },
                child: const Text("Move remaining tasks to tomorrow →"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppState appState, DateTime now) {
    final greetName = appState.userName.trim().isEmpty ? "" : ", ${appState.userName.trim()}";
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(weekdayFullOf(now).toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.muted)),
              const SizedBox(height: 3),
              Text("${greetingFor(now)}$greetName 👋",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            ],
          ),
        ),
        _bellButton(context, appState),
      ],
    );
  }

  Widget _bellButton(BuildContext context, AppState appState) {
    final unread = appState.unreadNotificationCount;
    return GestureDetector(
      onTap: () => showNotificationsSheet(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ]),
        child: Stack(
          children: [
            const Center(child: Icon(Icons.notifications_outlined, color: AppColors.muted, size: 20)),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.brick, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, int left, int done, int working, int pending, int total) {
    final headline = total == 0
        ? "Add your first task"
        : left == 0
            ? "All done for today 🎉"
            : "$left task${left == 1 ? '' : 's'} left today";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, Color(0xFFEDE4CF)],
        ),
        border: Border.all(color: const Color(0xFFD8C9A8)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          TrackProgressBar(done: done, working: working, pending: pending),
          const SizedBox(height: 10),
          Text("$done done · $working working · $pending pending",
              style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusScreen())),
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: const Text("Start Focus"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prioritiesHeader(BuildContext context, AppState appState, int soonerTotal) {
    final atLimit = soonerTotal >= appState.dailyLimit;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("TODAY'S PRIORITIES",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: AppColors.text)),
        Row(
          children: [
            Text("$soonerTotal / ${appState.dailyLimit}",
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: atLimit ? AppColors.brick : AppColors.muted)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => showAppBottomSheet(context, const TaskSheet(initialBucket: TaskBucket.sooner)),
              child: const Icon(Icons.add_circle, color: AppColors.accent, size: 27),
            ),
          ],
        ),
      ],
    );
  }

  Widget _laterHeader(BuildContext context, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("LATER",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: AppColors.text)),
        Row(
          children: [
            Text("$count", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => showAppBottomSheet(context, const TaskSheet(initialBucket: TaskBucket.later)),
              child: const Icon(Icons.add_circle, color: AppColors.accent, size: 27),
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyReviewCard extends StatefulWidget {
  const _DailyReviewCard();

  @override
  State<_DailyReviewCard> createState() => _DailyReviewCardState();
}

class _DailyReviewCardState extends State<_DailyReviewCard> {
  ReviewMood? _mood;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.green.withOpacity(0.16), AppColors.green.withOpacity(0.05)],
        ),
        border: Border.all(color: AppColors.green),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("How was today?", style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.greenDark)),
          const SizedBox(height: 12),
          Row(
            children: ReviewMood.values.map((m) {
              final on = m == _mood;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: m == ReviewMood.values.last ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _mood = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.green : AppColors.surface,
                        border: Border.all(color: on ? AppColors.green : AppColors.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 2),
                          Text(m.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: on ? AppColors.onAccent : AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(hintText: "What did you learn? (optional)"),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: _mood == null
                  ? null
                  : () async {
                      await appState.saveTodayReview(_mood!, _noteCtrl.text.trim());
                    },
              child: const Text("Save review"),
            ),
          ),
        ],
      ),
    );
  }
}
