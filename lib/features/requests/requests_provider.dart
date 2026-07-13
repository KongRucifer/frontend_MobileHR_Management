import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';

List<Map<String, dynamic>> _asList(dynamic data) =>
    ((data as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

/// Read-only leave approval chain (who will approve — employee can't choose).
final leaveChainProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/requests/leave-chain');
  return _asList(res.data);
});

/// Active sick/illness types (for the request form).
final sickTypesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/requests/sick-types');
  return _asList(res.data);
});

/// The pool of approvers the employee may pick ONE from for a sick request.
final sickPoolProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/requests/sick-approvers');
  return _asList(res.data);
});

/// The logged-in employee's own leave requests (with step progress).
final myLeaveProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/requests/leave/mine');
  return _asList(res.data);
});

/// The logged-in employee's own sick requests.
final mySickProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/requests/sick/mine');
  return _asList(res.data);
});

/// Combined inbox of leave + sick requests this user can act on / has acted on.
final inboxProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/requests/inbox');
  return _asList(res.data);
});

/// Notifications for the bell.
final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/notifications');
  return _asList(res.data);
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await Api.dio.get('/notifications/unread-count');
  final data = res.data;
  return (data is Map ? (data['count'] ?? 0) : 0) as int;
});

/// Mutations (kept as plain calls; pages invalidate the relevant providers).
class RequestsApi {
  static Future<void> createLeave({
    required String reason,
    required String startDate,
    required String endDate,
  }) async {
    await Api.dio.post('/requests/leave', data: {
      'reason': reason,
      'startDate': startDate,
      'endDate': endDate,
    });
  }

  static Future<void> createSick({
    required String sickTypeId,
    required String approverUserId,
    required String reason,
  }) async {
    await Api.dio.post('/requests/sick', data: {
      'sickTypeId': sickTypeId,
      'approverUserId': approverUserId,
      'reason': reason,
    });
  }

  static Future<void> decide({
    required String type, // 'leave' | 'sick'
    required String id,
    required bool approve,
    String? comment,
  }) async {
    await Api.dio.patch('/requests/$type/$id/decide', data: {
      'approve': approve,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  static Future<void> markAllRead() async {
    await Api.dio.patch('/notifications/read-all');
  }
}
