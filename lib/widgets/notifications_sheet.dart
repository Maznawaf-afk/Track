import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../date_utils.dart';
import '../theme.dart';
import 'common.dart';

Future<void> showNotificationsSheet(BuildContext context) async {
  final appState = AppStateScope.read(context);
  await appState.markAllNotificationsRead();
  if (!context.mounted) return;
  await showAppBottomSheet(context, const _NotificationsSheetContent());
}

class _NotificationsSheetContent extends StatelessWidget {
  const _NotificationsSheetContent();

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: appState.notifications.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text("No notifications yet.\nEnable reminders below to get daily nudges.",
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: appState.notifications.length,
                    itemBuilder: (context, i) {
                      final n = appState.notifications[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: n.read ? null : const Border(left: BorderSide(color: AppColors.accent, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(n.body, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
                            const SizedBox(height: 6),
                            Text(timeAgo(n.time), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Reminders", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(
                      appState.remindersOn
                          ? "Morning & evening nudges active."
                          : "Morning (8am) & evening (6pm) nudges, plus event alerts.",
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: appState.remindersOn,
                activeColor: AppColors.green,
                onChanged: (v) => appState.setRemindersOn(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
