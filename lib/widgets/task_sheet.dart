import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../date_utils.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

/// Bottom sheet used for both creating a new task and editing an existing
/// one. Pass [existing] to edit; omit it to add. Also the entry point for
/// setting up a recurring task (repeat picker, add mode only).
class TaskSheet extends StatefulWidget {
  final TaskItem? existing;
  final TaskBucket? initialBucket;
  const TaskSheet({super.key, this.existing, this.initialBucket});

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  late final TextEditingController _textCtrl;
  late Difficulty _difficulty;
  late TaskCategory _category;
  late TaskBucket _bucket;
  DateTime? _dueDate;
  RecurrenceType _repeatType = RecurrenceType.none;
  final Set<int> _repeatDays = {};

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _textCtrl = TextEditingController(text: t?.text ?? "");
    _difficulty = t?.difficulty ?? Difficulty.normal;
    _category = t?.category ?? TaskCategory.other;
    _bucket = t?.bucket ?? widget.initialBucket ?? TaskBucket.sooner;
    _dueDate = t?.dueDate;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = todayDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = dateOnly(picked));
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: "Delete task?", message: 'Delete "${widget.existing!.text}"?', confirmLabel: "Delete", danger: true);
    if (!ok || !mounted) return;
    final appState = AppStateScope.read(context);
    await appState.deleteTask(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final appState = AppStateScope.read(context);
    final text = _textCtrl.text.trim();
    final problem = appState.validateTaskText(
      text,
      bucket: _bucket,
      date: todayDate(),
      excludeId: widget.existing?.id,
    );

    if (problem == TaskTextProblem.tooShort) {
      showToast(context, "Give it at least 3 characters.");
      return;
    }
    if (problem == TaskTextProblem.noLetterOrDigit) {
      showToast(context, "Add some letters or numbers — not just symbols or emoji.");
      return;
    }
    if (problem == TaskTextProblem.duplicate) {
      final proceed = await confirmDialog(
        context,
        title: "Already on your list",
        message: '"$text" already exists in this bucket today. Add it anyway?',
        confirmLabel: "Add anyway",
      );
      if (!proceed || !mounted) return;
    }

    if (_bucket == TaskBucket.sooner) {
      final existingCount = appState
          .bucketTasksOn(TaskBucket.sooner, todayDate())
          .where((t) => t.id != widget.existing?.id)
          .length;
      if (existingCount >= appState.dailyLimit) {
        final proceed = await confirmDialog(
          context,
          title: "At your daily focus",
          message:
              "You're at your ${appState.dailyLimit}-task focus for Sooner. Add \"$text\" as an extra anyway?",
          confirmLabel: "Add extra",
        );
        if (!proceed || !mounted) return;
      }
    }

    if (isEdit) {
      await appState.updateTask(
        widget.existing!.id,
        text: text,
        difficulty: _difficulty,
        category: _category,
        bucket: _bucket,
        dueDate: _bucket == TaskBucket.later ? _dueDate : null,
      );
    } else if (_repeatType != RecurrenceType.none) {
      await appState.addRecurring(RecurringTemplate(
        id: newId(),
        text: text,
        difficulty: _difficulty,
        category: _category,
        bucket: _bucket,
        rule: RecurrenceRule(
          type: _repeatType,
          weekdays: _repeatType == RecurrenceType.weekly ? _repeatDays.toList() : [],
        ),
      ));
    } else {
      await appState.addTask(
        text: text,
        difficulty: _difficulty,
        category: _category,
        bucket: _bucket,
        dueDate: _bucket == TaskBucket.later ? _dueDate : null,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final linkedToRecurring = widget.existing?.recurringId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEdit ? "Edit task" : "Add task", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (linkedToRecurring)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text("Part of a repeating task — this edits today's occurrence only.",
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            maxLength: 140,
            autofocus: !isEdit,
            decoration: const InputDecoration(hintText: "What do you need to do?", counterText: ""),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          _fieldLabel("Difficulty"),
          _segRow(
            options: Difficulty.values,
            selected: _difficulty,
            labelOf: (d) => d.label,
            colorOf: (d) => difficultyColor(d),
            onSelect: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 14),
          _fieldLabel("Category"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TaskCategory.values.map((c) {
              final on = c == _category;
              return ChoiceChip(
                label: Text("${c.emoji} ${c.label}"),
                selected: on,
                onSelected: (_) => setState(() => _category = c),
                selectedColor: AppColors.text,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                    color: on ? AppColors.onAccent : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
                side: BorderSide(color: on ? AppColors.text : AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _fieldLabel("When"),
          _segRow(
            options: TaskBucket.values,
            selected: _bucket,
            labelOf: (b) => b == TaskBucket.sooner ? "Sooner" : "Later",
            colorOf: (_) => AppColors.text,
            onSelect: (b) => setState(() => _bucket = b),
          ),
          if (_bucket == TaskBucket.later) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.field,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 18, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Text(
                      _dueDate == null ? "No due date — set one" : "Due: ${prettyDate(_dueDate!)}",
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    if (_dueDate != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (!isEdit) ...[
            const SizedBox(height: 14),
            _fieldLabel("Repeat"),
            _segRow(
              options: RecurrenceType.values,
              selected: _repeatType,
              labelOf: (r) => switch (r) {
                RecurrenceType.none => "Once",
                RecurrenceType.daily => "Daily",
                RecurrenceType.weekly => "Weekly",
              },
              colorOf: (_) => AppColors.purple,
              onSelect: (r) => setState(() => _repeatType = r),
            ),
            if (_repeatType == RecurrenceType.weekly) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(7, (i) {
                  final on = _repeatDays.contains(i);
                  return GestureDetector(
                    onTap: () => setState(() => on ? _repeatDays.remove(i) : _repeatDays.add(i)),
                    child: Container(
                      width: 40,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.purple : AppColors.surface,
                        border: Border.all(color: on ? AppColors.purple : AppColors.line),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(kWeekdayShort[i],
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: on ? AppColors.onAccent : AppColors.muted)),
                    ),
                  );
                }),
              ),
            ],
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (isEdit)
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.brick),
                  child: const Text("Delete"),
                ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(isEdit ? "Save changes" : "Add task"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5)),
      );

  Widget _segRow<T>({
    required List<T> options,
    required T selected,
    required String Function(T) labelOf,
    required Color Function(T) colorOf,
    required void Function(T) onSelect,
  }) {
    return Row(
      children: options.map((o) {
        final on = o == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: o == options.last ? 0 : 6),
            child: GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: on ? colorOf(o) : AppColors.surface,
                  border: Border.all(color: on ? colorOf(o) : AppColors.line),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labelOf(o),
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? AppColors.onAccent : AppColors.muted),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
