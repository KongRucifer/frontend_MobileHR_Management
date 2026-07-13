import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n.dart';
import 'notifications_page.dart';
import 'requests_provider.dart';

/// yyyy-MM-dd for the API.
String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Pretty date for display (dd MMM yyyy), tolerant of null / ISO strings.
String prettyDate(dynamic iso) {
  if (iso == null) return '--';
  final d = DateTime.tryParse(iso.toString());
  return d == null ? iso.toString() : DateFormat('dd MMM yyyy').format(d);
}

Color statusColor(String status) {
  switch (status) {
    case 'approved':
      return Colors.green.shade600;
    case 'rejected':
      return Colors.red.shade600;
    default:
      return Colors.amber.shade700; // pending
  }
}

/// AppBar notification bell with an unread badge.
class NotifBell extends ConsumerWidget {
  const NotifBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider).value ?? 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared TabBar styling: white labels in both states (sits on the blue AppBar).
TabBar whiteTabBar({
  required TabController controller,
  required List<Widget> tabs,
}) {
  return TabBar(
    controller: controller,
    tabs: tabs,
    labelColor: Colors.white,
    unselectedLabelColor: Colors.white,
    indicatorColor: Colors.white,
    indicatorWeight: 3,
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
  );
}

/// Small coloured pill for a request status (pending / approved / rejected).
Widget statusChip(String status, String lang) {
  final c = statusColor(status);
  final label = tr('st_$status', lang);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}
