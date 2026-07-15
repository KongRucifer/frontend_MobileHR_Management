import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../models/attendance.dart';
import '../requests/request_widgets.dart' show ymd;

/// Date range + optional status/kind filter for the history queries.
///
/// `==` / `hashCode` are MANDATORY: `family` caches provider instances by
/// argument equality. Without them every rebuild constructs a fresh (unequal)
/// key, autoDispose tears down the old instance, and the page refetches in an
/// endless loop.
@immutable
class HistoryFilter {
  final String from; // 'yyyy-MM-dd'
  final String to;

  /// One of: null (all) | 'on_time' | 'late' | 'absent' | 'leave' | 'emergency'.
  /// leave/emergency are sent as `kind` (FK-based) because a partial-day
  /// emergency keeps status 'on_time' and would be missed by a status filter.
  final String? status;

  const HistoryFilter({required this.from, required this.to, this.status});

  bool get _isKind => status == 'leave' || status == 'emergency';

  Map<String, dynamic> toQuery({int limit = 100}) => {
        'dateFrom': from,
        'dateTo': to,
        'limit': limit, // the backend caps limit at 100
        if (_isKind) 'kind': status,
        if (status != null && !_isKind) 'status': status,
      };

  HistoryFilter copyWith({String? from, String? to, Object? status = _unset}) =>
      HistoryFilter(
        from: from ?? this.from,
        to: to ?? this.to,
        status: status == _unset ? this.status : status as String?,
      );

  static const _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      other.from == from &&
      other.to == to &&
      other.status == status;

  @override
  int get hashCode => Object.hash(from, to, status);
}

/// First..last day of the month containing [ref] (defaults to today).
HistoryFilter currentMonth({DateTime? ref, String? status}) {
  final n = ref ?? DateTime.now();
  final last = DateTime(n.year, n.month + 1, 0).day;
  return HistoryFilter(
    from: ymd(DateTime(n.year, n.month, 1)),
    to: ymd(DateTime(n.year, n.month, last)),
    status: status,
  );
}

/// Range shown on the summary tab. Lives outside the widget so the user's
/// chosen month survives tab switches (main_shell only invalidates the data).
final summaryRangeProvider =
    StateProvider<HistoryFilter>((ref) => currentMonth());

/// Range + status shown on the pushed detail page — independent of the summary.
final detailFilterProvider =
    StateProvider<HistoryFilter>((ref) => currentMonth());

/// Day counts for the logged-in employee. Counters OVERLAP (a partial-day
/// emergency is both on_time and emergency) — never sum them.
final attendanceSummaryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, HistoryFilter>((ref, f) async {
  final res = await Api.dio.get(
    '/working/attendance/summary',
    queryParameters: {'dateFrom': f.from, 'dateTo': f.to},
  );
  return Map<String, dynamic>.from(res.data as Map);
});

/// The employee's own check-in/out rows for a range (+ optional status filter).
final attendanceHistoryProvider = FutureProvider.autoDispose
    .family<List<Attendance>, HistoryFilter>((ref, f) async {
  final res = await Api.dio.get(
    '/working/attendance/history',
    queryParameters: f.toQuery(),
  );
  final items = (res.data['items'] as List?) ?? [];
  return items
      .map((e) => Attendance.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});
