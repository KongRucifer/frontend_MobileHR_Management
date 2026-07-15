import 'dart:async';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../approvals/inbox_page.dart';
import '../history/history_page.dart';
import '../history/history_provider.dart';
import '../home/home_page.dart';
import '../home/home_provider.dart';
import '../profile/profile_page.dart';
import '../requests/my_requests_page.dart';
import '../requests/requests_page.dart';
import '../requests/requests_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  StreamSubscription<RemoteMessage>? _msgSub;

  @override
  void initState() {
    super.initState();
    // When a push arrives while the app is open, refresh the bell badge + list
    // (the sound itself is handled by PushService).
    _msgSub = FirebaseMessaging.onMessage.listen((_) {
      ref.invalidate(unreadCountProvider);
      ref.invalidate(notificationsProvider);
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    super.dispose();
  }

  static const _pages = [
    HomePage(),
    RequestsPage(),
    MyRequestsPage(),
    InboxPage(),
    HistoryPage(),
    ProfilePage(),
  ];
  static const _icons = [
    Icons.home_rounded,
    Icons.note_add_rounded,
    Icons.receipt_long_rounded,
    Icons.fact_check_rounded,
    Icons.history_rounded,
    Icons.person_rounded,
  ];

  /// IndexedStack keeps every page alive, so their autoDispose providers never
  /// re-fetch on their own. Invalidate the relevant ones when a tab is opened
  /// so it always shows fresh data.
  void _refreshFor(int i) {
    switch (i) {
      case 2: // My requests
        ref.invalidate(myLeaveProvider);
        ref.invalidate(myEmergencyProvider);
        break;
      case 3: // Manage leave (inbox)
        ref.invalidate(inboxProvider);
        ref.invalidate(unreadCountProvider);
        break;
      case 4: // Work history (summary)
        // Invalidating the family ROOT drops every cached range. The chosen
        // month lives in summaryRangeProvider (a StateProvider outside the
        // widget), so it survives — only the data refetches.
        ref.invalidate(attendanceSummaryProvider);
        ref.invalidate(attendanceHistoryProvider);
        ref.invalidate(todayProvider);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: DecoratedBox(
        // Shadow along the top edge of the bar (makes it float above content).
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: CurvedNavigationBar(
          index: _index,
          height: 62,
          backgroundColor: Colors.transparent,
          color: Theme.of(context).colorScheme.surface,
          buttonBackgroundColor: kBrand,
          animationCurve: Curves.easeOutCubic,
          animationDuration: const Duration(milliseconds: 350),
          items: [
            for (int i = 0; i < _icons.length; i++)
              Icon(
                _icons[i],
                size: 26,
                color: i == _index
                    ? Colors.white
                    : onSurface.withValues(alpha: 0.45),
              ),
          ],
          onTap: (i) {
            _refreshFor(i);
            setState(() => _index = i);
          },
        ),
      ),
    );
  }
}
