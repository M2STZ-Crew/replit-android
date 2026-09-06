import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

import '../api/api_client.dart';
import '../screens/notifications_screen.dart';

const Color _red = AppColors.live;

/// A bell icon button (40×40, matching the app-bar icon boxes) with an unread
/// badge. Tap opens the in-app notification inbox. Polls the unread count every
/// 20 s and refreshes on return. Drop into any top bar.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final ApiClient _api = ApiClient();
  Timer? _timer;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final n = await _api.getUnreadNotificationCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      // leave the last known count
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.onBackground,
                size: 19,
              ),
            ),
            if (_unread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  constraints: const BoxConstraints(minWidth: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: Text(
                    _unread > 9 ? '9+' : '$_unread',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onBackground,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
