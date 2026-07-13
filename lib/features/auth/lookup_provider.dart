import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';

/// Departments (public endpoint) for the register form.
final departmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/departments');
  return (res.data as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});

/// Positions (public endpoint) for the register form.
final positionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Api.dio.get('/positions');
  return (res.data as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});
