import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/i18n.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../models/attendance.dart';
import '../requests/request_widgets.dart';
import 'history_provider.dart';

/// The detailed check-in / check-out list, with its own date + status filter
/// (independent of the summary tab's month).
class HistoryDetailPage extends ConsumerWidget {
  const HistoryDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    final filter = ref.watch(detailFilterProvider);
    final listAsync = ref.watch(attendanceHistoryProvider(filter));

    return Scaffold(
      appBar: AppBar(title: Text(tr('check_in_history', lang))),
      body: Column(
        children: [
          _FilterBar(filter: filter, lang: lang),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(tr('no_history', lang))),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      tr('no_history', lang),
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(attendanceHistoryProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, kNavInset),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _Row(a: items[i], lang: lang),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.lang});
  final HistoryFilter filter;
  final String lang;

  /// History browses the PAST — bounds must look backwards. (The request forms'
  /// picker is forward-facing and is deliberately not reused here.)
  Future<DateTime?> _pick(BuildContext c, String iso) => showDatePicker(
        context: c,
        initialDate: DateTime.parse('${iso}T00:00:00'),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (c, child) => Theme(
          data: Theme.of(c).copyWith(
            colorScheme: Theme.of(c).colorScheme.copyWith(primary: kBrand),
          ),
          child: child!,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = <MapEntry<String?, String>>[
      MapEntry(null, tr('all', lang)),
      MapEntry('leave', tr('status_leave', lang)),
      MapEntry('emergency', tr('status_emergency', lang)),
      MapEntry('late', tr('status_late', lang)),
      MapEntry('absent', tr('status_absent', lang)),
      MapEntry('on_time', tr('status_on_time', lang)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateBox(
                  label: tr('start_date', lang),
                  value: filter.from,
                  onTap: () async {
                    final d = await _pick(context, filter.from);
                    if (d != null) {
                      ref.read(detailFilterProvider.notifier).state =
                          filter.copyWith(from: ymd(d));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateBox(
                  label: tr('end_date', lang),
                  value: filter.to,
                  onTap: () async {
                    final d = await _pick(context, filter.to);
                    if (d != null) {
                      ref.read(detailFilterProvider.notifier).state =
                          filter.copyWith(to: ymd(d));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final o = options[i];
                final selected = filter.status == o.key;
                return GestureDetector(
                  onTap: () => ref.read(detailFilterProvider.notifier).state =
                      filter.copyWith(status: o.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? kBrand : Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selected ? kBrand : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Text(
                      o.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(prettyDate(value), style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.a, required this.lang});
  final Attendance a;
  final String lang;

  String _t(DateTime? d) => d == null ? '--:--' : DateFormat('HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(a.workDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kBrand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              date != null ? DateFormat('dd').format(date) : '--',
              style: const TextStyle(fontWeight: FontWeight.bold, color: kBrand),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        date != null
                            ? DateFormat('EEE, dd MMM yyyy').format(date)
                            : a.workDate,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    // The label rides next to the date, driven by the FK.
                    if (a.requestKind != null) ...[
                      const SizedBox(width: 6),
                      _KindChip(a: a, lang: lang),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${tr('in_at', lang)}: ${_t(a.checkInTime)}   '
                  '${tr('out_at', lang)}: ${_t(a.checkOutTime)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(a.workHours != null ? '${a.workHours}h' : '-',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(tr('status_${a.status}', lang),
                  style: const TextStyle(fontSize: 11, color: kBrand)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.a, required this.lang});
  final Attendance a;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final isLeave = a.requestKind == 'leave';
    final c = isLeave ? kBrand : Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        a.requestTypeName ?? tr('status_${a.requestKind}', lang),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}
