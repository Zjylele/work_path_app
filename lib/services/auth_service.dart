import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// 登录态服务（基于 shared_preferences 本地持久化）
///
/// 阶段二起以 **token** 为登录态核心：
/// - [login] 调后端 `/api/user/login`，成功存 token + username
/// - [logout] 调后端 `/api/user/logout`，本地必清（接口失败不阻塞登出）
/// - [isLoggedIn] / [getUsername] 基于本地 token 判断
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _kToken = 'auth_token';
  static const _kUsername = 'auth_username';

  /// 认证 API 实现，默认走 [ApiClient]；单测可替换为 Fake
  static AuthApi api = ApiClient.instance;

  /// 登录：调后端校验，成功存 token + username 并注入请求层；失败抛 [ApiException]
  Future<void> login(String username, String password) async {
    final data = await api.login(username, password);
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException(0, '登录失败：未返回 token');
    }
    final user = data['user'];
    final storedUsername = user is Map<String, dynamic>
        ? ((user['username'] as String?) ?? username)
        : username;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUsername, storedUsername);
    ApiClient.instance.setToken(token);
  }

  /// 注册新用户（不自动登录，成功后回登录页手动登录）
  Future<void> register(String username, String password, String nickname) async {
    await api.register(username, password, nickname);
  }

  /// 退出登录：调后端登出，本地登录态必清（后端失败不阻塞）
  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // 后端登出失败（如 token 失效/断网）不阻塞本地登出
    } finally {
      ApiClient.instance.setToken(null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kUsername);
    }
  }

  /// 当前是否已登录：本地存在有效 token
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    return token != null && token.isNotEmpty;
  }

  /// 当前登录用户名/手机号
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUsername);
  }

  /// 当前 token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  /// 清除本地登录态（启动校验 token 失效时调用）
  Future<void> clearLocalLogin() async {
    ApiClient.instance.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUsername);
  }

  /// 启动校验本地登录态（调 `/api/user/info` 校验 token 有效性）
  ///
  /// 返回 true 表示可进入首页，false 表示需重新登录：
  /// - 无本地 token → false
  /// - token 有效 → true（并注入请求层）
  /// - token 失效（401）→ 清除本地登录态，false
  /// - 网络异常（连不上后端）→ 放行，true（信任本地 token，避免断网无法使用本地轨迹）
  Future<bool> validateOnStartup() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    ApiClient.instance.setToken(token);
    try {
      await api.info();
      return true;
    } on ApiException catch (e) {
      if (e.code == 401) {
        await clearLocalLogin();
        return false;
      }
      return true;
    }
  }
}
