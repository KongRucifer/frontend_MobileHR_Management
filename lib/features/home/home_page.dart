import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../models/attendance.dart';
import '../auth/auth_provider.dart';
import '../history/history_provider.dart';
import '../requests/request_widgets.dart';
import 'home_provider.dart';
import 'slide_action.dart';
import 'wifi_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check(bool isCheckIn, String lang) async {
    try {
      final wifi = await readWifi();
      final path = isCheckIn ? 'check-in' : 'check-out';
      await Api.dio.post('/working/attendance/$path', data: {
        'ssid': wifi.ssid ?? '',
        'bssid': wifi.bssid ?? '',
      });
      ref.invalidate(todayProvider);
      // Both: a check-in changes the day's row AND the month's workedDays count.
      ref.invalidate(attendanceSummaryProvider);
      ref.invalidate(attendanceHistoryProvider);
      _toast(
        tr(isCheckIn ? 'checkin_success' : 'checkout_success', lang),
        ok: true,
      );
    } catch (e) {
      _toast(Api.message(e), ok: false);
    }
  }

  void _toast(String msg, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          ok ? Colors.green.shade600 : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    final user = ref.watch(authProvider).user;
    final todayAsync = ref.watch(todayProvider);
    final schedule = ref.watch(myScheduleProvider).value;
    final name = user?.username ?? user?.email.split('@').first ?? '';
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final gray = onSurface.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_name', lang)),
        actions: const [NotifBell(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(todayProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavInset),
          children: [
            // ---- Welcome + live clock (white card) ----
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tr('hello', lang)}, $name 👋',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: gray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, dd/MM/yyyy').format(_now),
                    style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    DateFormat('HH:mm:ss').format(_now),
                    style: const TextStyle(
                      color: kBrand,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ---- Work schedule time (under welcome) ----
            if (schedule != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(color: gray, fontSize: 13),
                    children: [
                      TextSpan(text: '${tr('work_time_label', lang)} '),
                      TextSpan(
                        text: _hhmm(schedule['startTime']),
                        style: const TextStyle(
                          color: kBrand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' ${tr('to', lang)} '),
                      TextSpan(
                        text: _hhmm(schedule['endTime']),
                        style: const TextStyle(
                          color: kBrand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // ---- Today status (clean, no border/shadow/background) ----
            todayAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _todayCard(context, lang, null),
              data: (today) => _todayCard(context, lang, today),
            ),
            const SizedBox(height: 20),
            _slide(lang, todayAsync.value),
          ],
        ),
      ),
    );
  }

  /// "09:00:00" -> "09:00"
  String _hhmm(dynamic t) {
    final s = (t ?? '').toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Widget _todayCard(BuildContext context, String lang, Attendance? today) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final notCheckedIn = today == null || !today.checkedIn;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr('today_status', lang),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: onSurface.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              if (today != null && today.checkedIn)
                _statusBadge(today.status, lang),
            ],
          ),
          const SizedBox(height: 14),
          if (notCheckedIn)
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  tr('not_checked_in', lang),
                  style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _timeTile(
                      context, Icons.login, tr('in_at', lang), today.checkInTime),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeTile(context, Icons.logout, tr('out_at', lang),
                      today.checkOutTime),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _timeTile(
    BuildContext context,
    IconData icon,
    String label,
    DateTime? time,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: kBrand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: kBrand, size: 20),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            time == null ? '--:--' : DateFormat('HH:mm').format(time),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, String lang) {
    Color c;
    switch (status) {
      case 'late':
        c = Colors.amber.shade700;
        break;
      case 'absent':
        c = Colors.red.shade600;
        break;
      case 'leave':
        c = Colors.grey;
        break;
      default:
        c = Colors.green.shade600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tr('status_$status', lang),
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _slide(String lang, Attendance? today) {
    final checkedIn = today?.checkedIn ?? false;
    final checkedOut = today?.checkedOut ?? false;

    if (checkedOut) {
      return SlideAction(
        label: tr('done_today', lang),
        enabled: false,
        onActivate: () async {},
      );
    }
    final isCheckIn = !checkedIn;
    return SlideAction(
      label: isCheckIn ? tr('check_in', lang) : tr('check_out', lang),
      onActivate: () => _check(isCheckIn, lang),
    );
  }
}
