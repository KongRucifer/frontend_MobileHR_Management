import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/push_service.dart';
import '../../core/storage.dart';
import '../../models/user.dart';

class AuthState {
  final AppUser? user;
  final bool ready;
  const AuthState({this.user, this.ready = false});
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState()) {
    loadSession();
  }

  Future<void> loadSession() async {
    final token = await Storage.getToken();
    if (token == null) {
      state = const AuthState(user: null, ready: true);
      return;
    }
    try {
      final res = await Api.dio.get('/auth/me');
      state = AuthState(
        user: AppUser.fromJson(Map<String, dynamic>.from(res.data)),
        ready: true,
      );
      PushService.setup();
    } catch (_) {
      await Storage.clearToken();
      state = const AuthState(user: null, ready: true);
    }
  }

  /// Login is by username (email is only used for notifications / OTP).
  Future<void> login(String username, String password) async {
    final res = await Api.dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    await _apply(res.data);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String username,
    String? phone,
    String? birthDate,
    String? departmentId,
    String? positionId,
  }) async {
    final res = await Api.dio.post('/auth/register', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      'username': username,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate,
      if (departmentId != null) 'departmentId': departmentId,
      if (positionId != null) 'positionId': positionId,
    });
    await _apply(res.data);
  }

  Future<void> _apply(dynamic data) async {
    await Storage.saveTokens(
      data['accessToken'].toString(),
      (data['refreshToken'] ?? '').toString(),
    );
    state = AuthState(
      user: AppUser.fromJson(Map<String, dynamic>.from(data['user'])),
      ready: true,
    );
    PushService.setup();
  }

  Future<void> logout() async {
    try {
      await PushService.unregister();
      await Api.dio.post('/auth/logout');
    } catch (_) {}
    await Storage.clearToken();
    state = const AuthState(user: null, ready: true);
  }
}

final authProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController());
