import 'package:shared_preferences/shared_preferences.dart';

/// 登录态服务（基于 shared_preferences 本地持久化）
///
/// 阶段一使用内置管理员账号：admin / 123456。
/// 阶段二接入后端后将替换为真实接口校验，存储结构不变。
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _kLoggedIn = 'logged_in';
  static const _kUsername = 'logged_in_username';

  /// 内置管理员账号（阶段一）
  static const String adminUsername = 'admin';
  static const String adminPassword = '123456';

  /// 校验账号密码；成功则持久化登录态，返回是否登录成功
  Future<bool> login(String username, String password) async {
    if (username == adminUsername && password == adminPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLoggedIn, true);
      await prefs.setString(_kUsername, username);
      return true;
    }
    return false;
  }

  /// 清除登录态
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoggedIn);
    await prefs.remove(_kUsername);
  }

  /// 当前是否已登录
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  /// 当前登录用户名/手机号
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUsername);
  }
}
