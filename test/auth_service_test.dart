// AuthService 登录态逻辑的单元测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:work_path_test/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('正确账号 admin/123456 登录成功并持久化', () async {
    final ok = await AuthService.instance.login('admin', '123456');
    expect(ok, isTrue);
    expect(await AuthService.instance.isLoggedIn(), isTrue);
    expect(await AuthService.instance.getUsername(), 'admin');
  });

  test('错误密码登录失败，不写入登录态', () async {
    final ok = await AuthService.instance.login('admin', 'wrong');
    expect(ok, isFalse);
    expect(await AuthService.instance.isLoggedIn(), isFalse);
    expect(await AuthService.instance.getUsername(), isNull);
  });

  test('错误用户名登录失败', () async {
    final ok = await AuthService.instance.login('bob', '123456');
    expect(ok, isFalse);
  });

  test('退出登录清除登录态', () async {
    await AuthService.instance.login('admin', '123456');
    expect(await AuthService.instance.isLoggedIn(), isTrue);

    await AuthService.instance.logout();
    expect(await AuthService.instance.isLoggedIn(), isFalse);
    expect(await AuthService.instance.getUsername(), isNull);
  });
}
