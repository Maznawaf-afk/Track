import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'app_state.dart';
import 'screens/onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrackApp());
}

class TrackApp extends StatefulWidget {
  const TrackApp({super.key});

  @override
  State<TrackApp> createState() => _TrackAppState();
}

class _TrackAppState extends State<TrackApp> with WidgetsBindingObserver {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appState.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      appState: _appState,
      child: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) {
          return MaterialApp(
            title: "Track",
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: !_appState.ready
                ? const _SplashScreen()
                : (_appState.onboarded ? const RootShell() : const OnboardingScreen()),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.check_rounded, color: AppColors.onAccent, size: 30),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
