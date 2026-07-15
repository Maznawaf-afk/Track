import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';

const List<String> kGoalOptions = [
  "🎓 Study",
  "💪 Health",
  "💼 Career",
  "🌱 Personal growth",
  "💰 Finance",
  "❤️ Relationships",
];

/// First-run flow: explains the app's philosophy before dumping the user
/// into a task list, then collects just enough to personalize day one —
/// name, goals, a realistic daily task limit, and a focus style.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  static const int _pageCount = 6;

  String _name = "";
  final Set<String> _goals = {};
  int _dailyLimit = 5;
  FocusStyle _style = FocusStyle.balanced;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, _pageCount - 1);
    _pages.animateToPage(next, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    final appState = AppStateScope.read(context);
    await appState.completeOnboarding(
      name: _name.trim(),
      goals: _goals.toList(),
      limit: _dailyLimit,
      style: _style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pageCount, (i) {
                final on = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: on ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: on ? AppColors.accent : AppColors.surface2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _welcomePage(),
                  _namePage(),
                  _goalsPage(),
                  _limitPage(),
                  _stylePage(),
                  _summaryPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shell({
    required String eyebrow,
    required String title,
    String? subtitle,
    required Widget content,
    required Widget primary,
    bool showBack = true,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14.5, color: AppColors.muted, height: 1.5)),
          ],
          const SizedBox(height: 24),
          Expanded(child: SingleChildScrollView(child: content)),
          Row(
            children: [
              if (showBack)
                TextButton(onPressed: () => _go(-1), child: const Text("Back"))
              else
                const SizedBox.shrink(),
              const Spacer(),
              primary,
            ],
          ),
        ],
      ),
    );
  }

  Widget _welcomePage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 40, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.check_rounded, color: AppColors.onAccent, size: 34),
          ),
          const SizedBox(height: 24),
          const Text("Welcome to Track", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          const Text("Plan less. Finish more.",
              style: TextStyle(fontSize: 16, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          const Text(
            "Track keeps you focused on a short list of what actually matters today — instead of an endless backlog. Let's set it up for you.",
            style: TextStyle(fontSize: 14.5, color: AppColors.text, height: 1.55),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => _go(1), child: const Text("Get started")),
          ),
        ],
      ),
    );
  }

  Widget _namePage() {
    return _shell(
      eyebrow: "Step 1 of 4",
      title: "What should we call you?",
      subtitle: "Used for a friendly greeting on your Today screen.",
      content: TextField(
        autofocus: true,
        maxLength: 30,
        decoration: const InputDecoration(hintText: "Your name (optional)", counterText: ""),
        onChanged: (v) => _name = v,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _go(1),
      ),
      primary: ElevatedButton(onPressed: () => _go(1), child: const Text("Continue")),
    );
  }

  Widget _goalsPage() {
    return StatefulBuilder(builder: (context, setLocal) {
      return _shell(
        eyebrow: "Step 2 of 4",
        title: "What are your main goals?",
        subtitle: "Pick as many as apply — this just helps tailor suggestions later.",
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kGoalOptions.map((g) {
            final on = _goals.contains(g);
            return ChoiceChip(
              label: Text(g),
              selected: on,
              onSelected: (_) => setLocal(() => on ? _goals.remove(g) : _goals.add(g)),
              selectedColor: AppColors.text,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(color: on ? AppColors.onAccent : AppColors.text, fontWeight: FontWeight.w600),
              side: BorderSide(color: on ? AppColors.text : AppColors.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            );
          }).toList(),
        ),
        primary: ElevatedButton(onPressed: () => _go(1), child: const Text("Continue")),
      );
    });
  }

  Widget _limitPage() {
    return StatefulBuilder(builder: (context, setLocal) {
      return _shell(
        eyebrow: "Step 3 of 4",
        title: "How many tasks can you\nrealistically finish daily?",
        subtitle: "This becomes your Sooner-bucket focus limit — the app will nudge you when you go past it.",
        content: Column(
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stepperButton(Icons.remove, () {
                  if (_dailyLimit > 1) setLocal(() => _dailyLimit--);
                }),
                Container(
                  width: 90,
                  alignment: Alignment.center,
                  child: Text("$_dailyLimit",
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: AppColors.accentDark)),
                ),
                _stepperButton(Icons.add, () {
                  if (_dailyLimit < 12) setLocal(() => _dailyLimit++);
                }),
              ],
            ),
            const SizedBox(height: 6),
            const Text("important tasks / day", style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ],
        ),
        primary: ElevatedButton(onPressed: () => _go(1), child: const Text("Continue")),
      );
    });
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ]),
        child: Icon(icon, color: AppColors.text),
      ),
    );
  }

  Widget _stylePage() {
    return StatefulBuilder(builder: (context, setLocal) {
      return _shell(
        eyebrow: "Step 4 of 4",
        title: "Choose your focus style",
        subtitle: "Sets your default Focus-mode session length. You can change this later.",
        content: Column(
          children: FocusStyle.values.map((s) {
            final on = s == _style;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setLocal(() => _style = s),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: on ? AppColors.accent.withOpacity(0.12) : AppColors.surface,
                    border: Border.all(color: on ? AppColors.accent : AppColors.line, width: on ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                            const SizedBox(height: 3),
                            Text(s.description, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      Text("${s.pomodoroMinutes}m",
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accentDark)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        primary: ElevatedButton(onPressed: () => _go(1), child: const Text("Continue")),
      );
    });
  }

  Widget _summaryPage() {
    final greetName = _name.trim().isEmpty ? "" : ", ${_name.trim()}";
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 40, 26, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("You're all set$greetName 🎉", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Your daily limit is", style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("$_dailyLimit important tasks",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accentDark)),
                const SizedBox(height: 10),
                Text("Focus style: ${_style.label} · ${_style.pomodoroMinutes}-minute sessions",
                    style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _finish, child: const Text("Let's start")),
          ),
        ],
      ),
    );
  }
}
