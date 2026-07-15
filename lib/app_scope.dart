import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Makes the single [AppState] instance available anywhere below it via
/// `AppStateScope.of(context)`, and rebuilds dependents on
/// [AppState.notifyListeners]. A tiny hand-rolled stand-in for `provider`,
/// added to keep the dependency list (and therefore build risk) minimal.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState appState, required super.child}) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, "No AppStateScope found in context — wrap the app in one.");
    return scope!.notifier!;
  }

  /// Reads the state without subscribing to rebuilds — for one-off calls
  /// from event handlers.
  static AppState read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppStateScope>();
    assert(element != null, "No AppStateScope found in context — wrap the app in one.");
    return (element!.widget as AppStateScope).notifier!;
  }
}
