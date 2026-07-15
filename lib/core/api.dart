import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'storage.dart';

/// Base URL of the NestJS backend, read from .env (API_BASE_URL).
/// See .env.example for the values to use per platform:
/// - Physical device over USB: run `adb reverse tcp:3000 tcp:3000` once, then
///   localhost on the phone forwards to the PC's localhost:3000.
/// - Android emulator: use http://10.0.2.2:3000/api
/// - Physical device over WiFi: use the PC LAN IP, e.g. http://192.168.110.54:3000/api
String get kApiBaseUrl =>
    dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:3000/api';

class Api {
  static final Dio dio = _build();

  /// Bare client used only to call /auth/refresh (avoids interceptor recursion).
  static final Dio _refreshDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));

  static Future<bool>? _refreshing;

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await Storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Localize backend messages to the app language.
          options.headers['x-lang'] = Storage.lang;
          handler.next(options);
        },
        onResponse: (response, handler) {
          final body = response.data;
          if (body is Map && body.containsKey('data')) {
            response.data = body['data'];
          }
          handler.next(response);
        },
        onError: (e, handler) async {
          final p = e.requestOptions.path;
          final isAuthPath = p.contains('/auth/login') ||
              p.contains('/auth/register') ||
              p.contains('/auth/refresh');
          final alreadyRetried = e.requestOptions.extra['retried'] == true;

          if (e.response?.statusCode == 401 &&
              !isAuthPath &&
              !alreadyRetried) {
            _refreshing ??=
                _doRefresh().whenComplete(() => _refreshing = null);
            final ok = await _refreshing!;
            if (ok) {
              final req = e.requestOptions;
              req.extra['retried'] = true;
              final token = await Storage.getToken();
              req.headers['Authorization'] = 'Bearer $token';
              try {
                final clone = await dio.fetch(req);
                return handler.resolve(clone);
              } catch (err) {
                return handler.next(err as DioException);
              }
            }
          }
          handler.next(e);
        },
      ),
    );
    return dio;
  }

  /// Exchanges the stored refresh token for a new access + refresh pair.
  static Future<bool> _doRefresh() async {
    final rt = await Storage.getRefreshToken();
    if (rt == null) return false;
    try {
      final res = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': rt},
      );
      final data = (res.data is Map && res.data['data'] != null)
          ? res.data['data']
          : res.data;
      await Storage.saveTokens(
        data['accessToken'].toString(),
        data['refreshToken'].toString(),
      );
      return true;
    } catch (_) {
      await Storage.clearToken();
      return false;
    }
  }

  static String message(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        final m = data['message'];
        return m is List ? m.join(', ') : m.toString();
      }
      return e.message ?? 'Network error';
    }
    return e.toString();
  }
}
