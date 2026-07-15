import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../requests/request_widgets.dart';
import 'history_detail_page.dart';
import 'history_provider.dart';

/// Tab 4 — a monthly summary (day counts) plus a button into the detailed
/// check-in/check-out list. Defaults to the current month.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final range = ref.watch(summaryRangeProvider);
    final summaryAsync = ref.watch(attendanceSummaryProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('history', lang)),
        actions: const [NotifBell(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(attendanceSummaryProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavInset),
          children: [
            _MonthPicker(range: range, lang: lang),
            const SizedBox(height: 14),
            summaryAsync.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _Card(
                child: Text(
                  tr('no_history', lang),
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
              data: (s) => _SummaryCard(summary: s, lang: lang),
            ),
            const SizedBox(height: 14),
            _DetailButton(lang: lang),
          ],
        ),
      ),
    );
  }
}

/// Month stepper. Writing to the StateProvider re-keys the family, which
/// fetches the new month (and keeps the old one cached).
class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({required this.range, required this.lang});
  final HistoryFilter range;
  final String lang;

  void _shift(WidgetRef ref, int months) {
    final cur = DateTime.parse('${range.from}T00:00:00');
    final next = DateTime(cur.year, cur.month + months, 1);
    ref.read(summaryRangeProvider.notifier).state = currentMonth(ref: next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label =
        DateFormat('MMMM yyyy').format(DateTime.parse('${range.from}T00:00:00'));
    return _Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _shift(ref, -1),
          ),
          Column(
            children: [
              Text(tr('month', lang),
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _shift(ref, 1),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.lang});
  final Map<String, dynamic> summary;
  final String lang;

  int _n(String k) => (summary[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    // Counters overlap by design (a partial-day emergency is both on_time and
    // emergency) — they are listed, never summed.
    final rows = <_Stat>[
      _Stat(tr('status_leave', lang), _n('leaveDays'), kBrand),
      _Stat(tr('status_emergency', lang), _n('emergencyDays'), Colors.orange.shade700),
      _Stat(tr('status_absent', lang), _n('absentDays'), Colors.red.shade600),
      _Stat(tr('status_on_time', lang), _n('onTimeDays'), Colors.green.shade600),
      _Stat(tr('status_late', lang), _n('lateDays'), Colors.amber.shade700),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('summary', lang),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          for (final r in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.label)),
                  Text(
                    '${r.days} ${tr('day_unit', lang)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: r.color),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(tr('worked_days', lang),
                    style: TextStyle(color: Theme.of(context).hintColor)),
              ),
              Text(
                '${_n('workedDays')} ${tr('day_unit', lang)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.days, this.color);
  final String label;
  final int days;
  final Color color;
}

class _DetailButton extends StatelessWidget {
  const _DetailButton({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HistoryDetailPage()),
      ),
      child: _Card(
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: kBrand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tr('view_history_detail', lang),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Shared card shell: soft shadow, no border (matches the rest of the app).
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: child,
    );
  }
}
