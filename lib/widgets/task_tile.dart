import 'package:flutter/material.dart';

import '../date_utils.dart';
import '../models.dart';
import '../theme.dart';
import 'common.dart';

class TaskTile extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTapStatus;
  final VoidCallback onToggleBucket;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final bool allowCompleteSwipe;
  final int? number;

  const TaskTile({
    super.key,
    required this.task,
    required this.onTapStatus,
    required this.onToggleBucket,
    required this.onEdit,
    required this.onComplete,
    required this.onDelete,
    this.allowCompleteSwipe = true,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: ValueKey("dismiss-${task.id}"),
          direction: allowCompleteSwipe ? DismissDirection.horizontal : DismissDirection.endToStart,
          background: _swipeBg(alignLeft: true, color: AppColors.green, label: "✓ Done"),
          secondaryBackground: _swipeBg(alignLeft: false, color: AppColors.brick, label: "Delete"),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              return confirmDialog(
                context,
                title: "Delete task?",
                message: '"${task.text}" will be removed.',
                confirmLabel: "Delete",
                danger: true,
              );
            }
            return true;
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              onDelete();
            } else {
              onComplete();
            }
          },
          child: GestureDetector(
            onLongPress: onEdit,
            child: Container(
              decoration: BoxDecoration(
                color: difficultyTint(task.difficulty),
                border: Border(left: BorderSide(color: difficultyColor(task.difficulty), width: 4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Opacity(
                opacity: done ? 0.55 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (number != null)
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1, right: 10),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: AppColors.text, shape: BoxShape.circle),
                        child: Text("$number",
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.onAccent)),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.text,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.text,
                              decoration: done ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 9,
                                  runSpacing: 6,
                                  children: [
                                    difficultyTag(task.difficulty),
                                    categoryTag(task.category),
                                    if (task.carried)
                                      const Text("↻ carried",
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
                                    if (task.bucket == TaskBucket.later && task.dueDate != null)
                                      Text("Due: ${prettyDate(task.dueDate!)}",
                                          style: const TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.blueDark)),
                                    GestureDetector(
                                      onTap: onToggleBucket,
                                      child: Text(
                                        task.bucket == TaskBucket.sooner ? "→ Later" : "↑ Sooner",
                                        style: const TextStyle(
                                            fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopOnChange(
                                trigger: task.status,
                                child: GestureDetector(
                                  onTap: onTapStatus,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: statusColor(task.status),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      task.status.label,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: task.status == TaskStatus.pending ? AppColors.muted : AppColors.onAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _swipeBg({required bool alignLeft, required Color color, required String label}) {
    return Container(
      color: color,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(label, style: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}
