import 'package:flutter/material.dart';
import 'models.dart';

/// Colors ported 1:1 from the original web app's CSS custom properties.
class AppColors {
  static const bg = Color(0xFFEEE0CC);
  static const surface = Color(0xFFF6EFDF);
  static const surface2 = Color(0xFFE7D8BE);
  static const field = Color(0xFFFCF7ED);
  static const line = Color(0xFFDBC9AA);

  static const text = Color(0xFF34291F);
  static const muted = Color(0xFF8E7B61);

  static const accent = Color(0xFFBA6A4C);
  static const accentDark = Color(0xFFA35B3F);

  static const green = Color(0xFF607456);
  static const greenDark = Color(0xFF4F6147);

  static const brick = Color(0xFF7B2525);

  static const blue = Color(0xFF3A6186);
  static const blueDark = Color(0xFF2E5070);

  static const purple = Color(0xFF6B4A8A);
  static const amber = Color(0xFFB07A30);

  static const onAccent = Color(0xFFFBF5EA);

  static const easyBg = Color(0x1F607456);
  static const normalBg = Color(0x1FBA6A4C);
  static const hardBg = Color(0x1A7B2525);
}

Color difficultyColor(Difficulty d) => switch (d) {
      Difficulty.easy => AppColors.green,
      Difficulty.normal => AppColors.accent,
      Difficulty.hard => AppColors.brick,
    };

Color difficultyTint(Difficulty d) => switch (d) {
      Difficulty.easy => AppColors.easyBg,
      Difficulty.normal => AppColors.normalBg,
      Difficulty.hard => AppColors.hardBg,
    };

Color statusColor(TaskStatus s) => switch (s) {
      TaskStatus.working => AppColors.accent,
      TaskStatus.done => AppColors.green,
      TaskStatus.pending => AppColors.surface2,
    };

Color eventPriorityColor(EventPriority p) => switch (p) {
      EventPriority.low => AppColors.green,
      EventPriority.normal => AppColors.accent,
      EventPriority.high => AppColors.brick,
    };

const List<Color> kHabitColors = [
  AppColors.green,
  AppColors.accent,
  AppColors.blue,
  AppColors.purple,
  AppColors.amber,
  AppColors.brick,
];

const List<Color> kProjectColors = [
  AppColors.green,
  AppColors.accent,
  AppColors.blue,
  AppColors.purple,
  AppColors.amber,
  AppColors.brick,
];

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: "Roboto",
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.surface,
      primary: AppColors.accent,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.muted,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.muted),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: const TextStyle(color: AppColors.onAccent),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
