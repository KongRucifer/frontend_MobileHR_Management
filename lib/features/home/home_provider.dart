import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../models/attendance.dart';
import '../auth/auth_provider.dart';

/// The logged-in employee's assigned work schedule (start/end time), or null.
final myScheduleProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user?.employeeId == null) return null;
  final res = await Api.dio.get('/employees/${user!.employeeId}');
  final emp = Map<String, dynamic>.from(res.data);
  final sched = emp['workSchedule'];
  return sched == null ? null : Map<String, dynamic>.from(sched);
});

/// Today's attendance record for the logged-in employee (null if none yet).
final todayProvider = FutureProvider.autoDispose<Attendance?>((ref) async {
  final res = await Api.dio.get('/working/attendance/today');
  if (res.data == null) return null;
  return Attendance.fromJson(Map<String, dynamic>.from(res.data));
});

// Attendance history now lives in features/history/history_provider.dart as a
// family keyed by date range + status filter (see attendanceHistoryProvider).
