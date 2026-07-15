import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Plays a short fade + slide-down entrance the first time a widget with a
/// given [key] appears in the tree (e.g. `FadeSlideIn(key: ValueKey(task.id), ...)`).
/// Because Flutter keeps existing State alive when the key is unchanged,
/// re-rendering an already-visible item never replays the animation — only
/// genuinely new items do.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const FadeSlideIn({super.key, required this.child, this.duration = const Duration(milliseconds: 260)});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}

/// A brief scale "pop" — used for the checkmark burst when a task is
/// completed. Plays once on mount, driven purely by [trigger] changing.
class PopOnChange extends StatefulWidget {
  final Widget child;
  final Object trigger;
  const PopOnChange({super.key, required this.child, required this.trigger});

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late Animation<double> _scale = _buildScale();

  Animation<double> _buildScale() => TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant PopOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

Widget sectionHeader(String title, {Widget? trailing, String? meta}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 11),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.text,
          ),
        ),
        if (trailing != null) trailing,
        if (trailing == null && meta != null)
          Text(meta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
      ],
    ),
  );
}

Widget emptyState(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line, style: BorderStyle.solid),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
  );
}

Widget pillTag(String text, {required Color fg, Color? bg}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg ?? Colors.white.withOpacity(0.4),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: fg),
    ),
  );
}

Widget difficultyTag(Difficulty d) =>
    pillTag(d.label.toUpperCase(), fg: difficultyColor(d) == AppColors.brick ? AppColors.brick : difficultyColor(d));

Widget categoryTag(TaskCategory c) {
  if (c == TaskCategory.other) return const SizedBox.shrink();
  return pillTag("${c.emoji} ${c.label}", fg: AppColors.blueDark, bg: AppColors.blue.withOpacity(0.1));
}

/// Slim stacked progress bar (done / working / pending), matching the
/// original web app's `.bar` component, animated on value change.
class TrackProgressBar extends StatelessWidget {
  final int done;
  final int working;
  final int pending;
  const TrackProgressBar({super.key, required this.done, required this.working, required this.pending});

  @override
  Widget build(BuildContext context) {
    final total = (done + working + pending) == 0 ? 1 : (done + working + pending);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final doneW = w * done / total;
      final workW = w * working / total;
      return SizedBox(
        height: 10,
        width: w,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(999)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: doneW,
                    child: Container(color: AppColors.green),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    left: doneW,
                    top: 0,
                    bottom: 0,
                    width: workW,
                    child: Container(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = "Confirm",
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: danger ? AppColors.brick : AppColors.accent),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<T?> showAppBottomSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(top: false, child: child),
    ),
  );
}
