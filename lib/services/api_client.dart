import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// 认证相关后端 API 抽象（便于单测注入替身）
abstract class AuthApi {
  /// POST /api/user/login，成功返回 data（{ token, user }）
  Future<Map<String, dynamic>> login(String username, String password);

  /// POST /api/user/register（注册成功后前端回登录页手动登录）
  Future<void> register(String username, String password, String nickname);

  /// POST /api/user/logout（需带 token）
  Future<void> logout();

  /// GET /api/user/info，成功返回 data（{ id, username, nickname, role }）
  Future<Map<String, dynamic>> info();
}

/// API 业务异常：code 为后端业务码（200/400/401/403/404/409/500），
/// message 为后端返回的提示文案（网络异常时由客户端包装）。
class ApiException implements Exception {
  ApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'ApiException($code): $message';
}

/// 统一网络请求客户端（dio 单例）
///
/// - 请求拦截器：自动注入 `Authorization: Bearer <token>`
/// - 响应拦截器：后端统一 `{ code, message, data }`，code != 200 抛 [ApiException]
/// - 网络异常：包装为 [ApiException]（code=0）抛出
class ApiClient implements AuthApi {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final body = response.data;
          if (body is Map<String, dynamic>) {
            final code = body['code'];
            if (code != null && code != 200) {
              // token 失效（401）且请求带 token（非登录接口）→ 触发全局登出回调
              if (code == 401 &&
                  response.requestOptions.headers.containsKey('Authorization')) {
                onUnauthorized?.call();
              }
              handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType.badResponse,
                  error: ApiException(
                    code is int ? code : int.tryParse('$code') ?? -1,
                    (body['message'] as String?) ?? '请求失败',
                  ),
                ),
              );
              return;
            }
          }
          handler.next(response);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;

  /// 当前登录 token（内存缓存，登录成功 / 启动恢复时注入）
  String? _token;

  Dio get dio => _dio;

  /// token 失效（401）时触发的全局回调（用于清登录态并跳转登录页）
  void Function()? onUnauthorized;

  /// 设置当前登录 token（null 表示登出）
  void setToken(String? token) {
    _token = token;
  }

  /// 当前 token
  String? getToken() => _token;

  /// 统一处理：dio 异常 → ApiException
  Future<T> _unwrap<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      final apiError = e.error;
      if (apiError is ApiException) {
        throw apiError;
      }
      throw ApiException(0, '网络异常，请检查网络连接');
    }
  }

  /// POST /api/user/login，成功返回 data（{ token, user }）
  @override
  Future<Map<String, dynamic>> login(String username, String password) {
    return _unwrap(() async {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/user/login',
        data: {'username': username, 'password': password},
      );
      return (resp.data?['data'] as Map<String, dynamic>?) ?? const {};
    });
  }

  /// POST /api/user/register
  @override
  Future<void> register(String username, String password, String nickname) {
    return _unwrap(() async {
      await _dio.post<Map<String, dynamic>>(
        '/api/user/register',
        data: {'username': username, 'password': password, 'nickname': nickname},
      );
    });
  }

  /// PUT /api/user/profile，修改当前用户昵称，返回 data（user 信息）
  Future<Map<String, dynamic>> updateProfile(String nickname) {
    return _unwrap(() async {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/api/user/profile',
        data: {'nickname': nickname},
      );
      return (resp.data?['data'] as Map<String, dynamic>?) ?? const {};
    });
  }

  /// POST /api/user/logout（需带 token）
  @override
  Future<void> logout() {
    return _unwrap(() async {
      await _dio.post<Map<String, dynamic>>('/api/user/logout');
    });
  }

  /// GET /api/user/info，成功返回 data（{ id, username, nickname, role }）
  @override
  Future<Map<String, dynamic>> info() {
    return _unwrap(() async {
      final resp = await _dio.get<Map<String, dynamic>>('/api/user/info');
      return (resp.data?['data'] as Map<String, dynamic>?) ?? const {};
    });
  }

  /// POST /api/track/upload，成功返回 data（{ id }）
  Future<Map<String, dynamic>> uploadTrack(Map<String, dynamic> payload) {
    return _unwrap(() async {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/track/upload',
        data: payload,
      );
      return (resp.data?['data'] as Map<String, dynamic>?) ?? const {};
    });
  }
}
