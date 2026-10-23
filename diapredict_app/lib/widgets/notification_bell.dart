import 'package:flutter/material.dart';

import '../services/notification_center.dart';
import '../screens/clinician/notifications_screen.dart';

// Bell icon for the app bar, with a red badge showing unread notifications
class NotificationBell extends StatelessWidget {
  final String role;

  const NotificationBell({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationCenter.unread,
      builder: (context, count, _) {
        return IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationsScreen(role: role),
              ),
            );
          },
        );
      },
    );
  }
}
