// AuthService 登录态逻辑的单元测试（网络层用 Fake 替身）。
//
// 注意：AuthService.api 默认指向真实的 ApiClient（dio 直连后端），
// 单测里必须替换为 Fake，避免在测试环境中发起真实网络请求。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:work_path_test/services/api_client.dart';
import 'package:work_path_test/services/auth_service.dart';

/// 假后端：调用记录可控，返回值/异常可配置
class FakeAuthApi implements AuthApi {
  Map<String, dynamic> loginResult = {
    'token': 'fake-token',
    'user': {'id': 1, 'username': 'admin', 'nickname': '管理员', 'role': 'ADMIN'},
  };

  /// login 抛出的异常（非 null 时抛出）
  Object? loginError;

  /// logout 抛出的异常（非 null 时抛出）
  Object? logoutError;

  /// info 抛出的异常（非 null 时抛出）
  Object? infoError;

  int loginCalls = 0;
  int logoutCalls = 0;
  int infoCalls = 0;

  /// register 抛出的异常（非 null 时抛出）
  Object? registerError;

  int registerCalls = 0;

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return loginResult;
  }

  @override
  Future<void> register(String username, String password, String nickname) async {
    registerCalls++;
    if (registerError != null) throw registerError!;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<Map<String, dynamic>> info() async {
    infoCalls++;
    if (infoError != null) throw infoError!;
    return {'id': 1, 'username': 'admin', 'nickname': '管理员', 'role': 'ADMIN'};
  }
}

void main() {
  late FakeAuthApi fakeApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeApi = FakeAuthApi();
    AuthService.api = fakeApi;
    ApiClient.instance.setToken(null);
  });

  tearDown(() {
    AuthService.api = ApiClient.instance;
  });

  test('登录成功：存 token + username，isLoggedIn 为 true', () async {
    await AuthService.instance.login('admin', '123456');

    expect(fakeApi.loginCalls, 1);
    expect(await AuthService.instance.isLoggedIn(), isTrue);
    expect(await AuthService.instance.getUsername(), 'admin');
    expect(await AuthService.instance.getToken(), 'fake-token');
    expect(ApiClient.instance.getToken(), 'fake-token');
  });

  test('登录失败（401）抛 ApiException，不写登录态', () async {
    fakeApi.loginError = ApiException(401, '用户名或密码错误');

    await expectLater(
      AuthService.instance.login('admin', 'wrong'),
      throwsA(isA<ApiException>()),
    );
    expect(await AuthService.instance.isLoggedIn(), isFalse);
    expect(await AuthService.instance.getUsername(), isNull);
  });

  test('注册：调用后端 register，不写入登录态', () async {
    await AuthService.instance.register('newuser', '123456', '新人');
    expect(fakeApi.registerCalls, 1);
    expect(await AuthService.instance.isLoggedIn(), isFalse);
    expect(await AuthService.instance.getUsername(), isNull);
  });

  test('注册失败（409）抛 ApiException', () async {
    fakeApi.registerError = ApiException(409, '用户名已存在');
    await expectLater(
      AuthService.instance.register('admin', '123456', 'x'),
      throwsA(isA<ApiException>()),
    );
  });

  test('退出登录：调用后端 logout 并清除登录态', () async {
    await AuthService.instance.login('admin', '123456');
    expect(await AuthService.instance.isLoggedIn(), isTrue);

    await AuthService.instance.logout();
    expect(fakeApi.logoutCalls, 1);
    expect(await AuthService.instance.isLoggedIn(), isFalse);
    expect(await AuthService.instance.getUsername(), isNull);
    expect(ApiClient.instance.getToken(), isNull);
  });

  test('后端 logout 异常不阻塞本地登出', () async {
    await AuthService.instance.login('admin', '123456');
    fakeApi.logoutError = ApiException(401, 'token 已过期，请重新登录');

    await AuthService.instance.logout();
    expect(await AuthService.instance.isLoggedIn(), isFalse);
    expect(await AuthService.instance.getUsername(), isNull);
  });

  test('启动校验：token 有效进入首页', () async {
    await AuthService.instance.login('admin', '123456');

    final ok = await AuthService.instance.validateOnStartup();
    expect(ok, isTrue);
    expect(fakeApi.infoCalls, 1);
  });

  test('启动校验：token 失效（401）清本地登录态并返回 false', () async {
    await AuthService.instance.login('admin', '123456');
    fakeApi.infoError = ApiException(401, 'token 已过期，请重新登录');

    final ok = await AuthService.instance.validateOnStartup();
    expect(ok, isFalse);
    expect(await AuthService.instance.isLoggedIn(), isFalse);
    expect(ApiClient.instance.getToken(), isNull);
  });

  test('启动校验：网络异常放行进首页（信任本地 token）', () async {
    await AuthService.instance.login('admin', '123456');
    fakeApi.infoError = ApiException(0, '网络异常，请检查网络连接');

    final ok = await AuthService.instance.validateOnStartup();
    expect(ok, isTrue);
    expect(await AuthService.instance.isLoggedIn(), isTrue);
  });

  test('启动校验：无本地 token 返回 false，不发请求', () async {
    final ok = await AuthService.instance.validateOnStartup();
    expect(ok, isFalse);
    expect(fakeApi.infoCalls, 0);
  });
}
