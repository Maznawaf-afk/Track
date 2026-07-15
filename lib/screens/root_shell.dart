import 'package:flutter/material.dart';

import '../theme.dart';
import 'calendar_screen.dart';
import 'goals_screen.dart';
import 'habits_screen.dart';
import 'progress_screen.dart';
import 'projects_screen.dart';
import 'today_screen.dart';

/// Hosts the five (six, with Progress) main tabs behind a bottom nav bar,
/// keeping each tab's scroll position / local state alive via [IndexedStack].
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const List<Widget> _screens = [
    TodayScreen(),
    CalendarScreen(),
    ProjectsScreen(),
    HabitsScreen(),
    GoalsScreen(),
    ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IndexedStack(index: _index, children: _screens),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: "Today"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Calendar"),
          BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), label: "Projects"),
          BottomNavigationBarItem(icon: Icon(Icons.repeat), label: "Habits"),
          BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), label: "Goals"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Progress"),
        ],
      ),
    );
  }
}
