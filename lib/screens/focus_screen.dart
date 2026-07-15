import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../date_utils.dart';
import '../models.dart';
import '../theme.dart';

/// Focus mode: walks through today's remaining tasks one at a time with an
/// attached Pomodoro-style countdown timer.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  int _index = 0;
  Timer? _timer;
  bool _running = false;
  bool _inited = false;
  int _durationSeconds = 25 * 60;
  int _remaining = 25 * 60;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      final appState = AppStateScope.of(context);
      _durationSeconds = appState.focusStyle.pomodoroMinutes * 60;
      _remaining = _durationSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_remaining > 0) {
          _remaining--;
        } else {
          t.cancel();
          _running = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pomodoro complete — nice work! 🎉")),
          );
        }
      });
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remaining = _durationSeconds;
    });
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, "0");
    final s = (seconds % 60).toString().padLeft(2, "0");
    return "$m:$s";
  }

  List<TaskItem> _focusList(AppState appState) {
    final list = appState.tasksOn(todayDate()).where((t) => t.status != TaskStatus.done).toList();
    list.sort((a, b) {
      if (a.bucket != b.bucket) return a.bucket == TaskBucket.sooner ? -1 : 1;
      return a.status.rank.compareTo(b.status.rank);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final list = _focusList(appState);
    if (_index >= list.length) _index = 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    list.isEmpty ? "Done" : "Task ${_index + 1} of ${list.length}",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.muted),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Exit", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: list.isEmpty ? _emptyState() : _taskCard(appState, list[_index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Text("All clear for today 🎉",
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.muted));
  }

  Widget _taskCard(AppState appState, TaskItem task) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
            decoration: BoxDecoration(
              color: difficultyTint(task.difficulty),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  (task.bucket == TaskBucket.later ? "${task.difficulty.label} · later" : task.difficulty.label)
                      .toUpperCase(),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: difficultyColor(task.difficulty)),
                ),
                const SizedBox(height: 16),
                Text(
                  task.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _fmt(_remaining),
            style: const TextStyle(
                fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: 1, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: _resetTimer, child: const Text("Reset")),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _toggleTimer,
                child: Text(_running ? "Pause" : (_remaining == _durationSeconds ? "Start" : "Resume")),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () async {
                await appState.setStatus(task.id, TaskStatus.done);
              },
              child: const Text("Mark done"),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface, foregroundColor: AppColors.accentDark, elevation: 1, padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: task.status == TaskStatus.working
                  ? null
                  : () async {
                      await appState.setStatus(task.id, TaskStatus.working);
                      setState(() => _index++);
                    },
              child: Text(task.status == TaskStatus.working ? "Working on it ✓" : "I'm working on it"),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _index++),
            child: const Text("Skip for now →", style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
