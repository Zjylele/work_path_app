// 登录页与启动登录态检查的冒烟测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:work_path_test/main.dart';
import 'package:work_path_test/pages/home_page.dart';
import 'package:work_path_test/pages/login_page.dart';
import 'package:work_path_test/services/api_client.dart';
import 'package:work_path_test/services/auth_service.dart';
import 'package:work_path_test/services/track_database.dart';

/// 假后端：登录可控成功/失败，info/logout 恒成功
class _FakeAuthApi implements AuthApi {
  bool failLogin = false;

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    if (failLogin) {
      throw ApiException(401, '用户名或密码错误');
    }
    return {
      'token': 'fake-token',
      'user': {'id': 1, 'username': username, 'nickname': username, 'role': 'USER'},
    };
  }

  @override
  Future<void> register(String username, String password, String nickname) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<Map<String, dynamic>> info() async {
    return {'id': 1, 'username': 'admin', 'nickname': 'admin', 'role': 'USER'};
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // 首页会访问数据库，注入 FFI factory（内存库）
    TrackDatabase.instance.factoryOverride = databaseFactoryFfi;
    TrackDatabase.instance.pathOverride = inMemoryDatabasePath;
    await TrackDatabase.instance.close();

    // 替换网络层为假后端，避免测试发起真实请求
    AuthService.api = _FakeAuthApi();
  });

  tearDown(() {
    AuthService.api = ApiClient.instance;
  });

  testWidgets('未登录时启动进入登录页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('用户名/手机号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });

  testWidgets('已登录时启动直接进入首页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'fake-token',
      'auth_username': 'admin',
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('登录页正确账号可登录并跳转首页', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(await AuthService.instance.isLoggedIn(), isTrue);
  });

  testWidgets('登录页错误账号提示失败且不跳转', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    (AuthService.api as _FakeAuthApi).failLogin = true;

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('登录'));
    await tester.pump();

    // 仍停留在登录页，并显示失败提示
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('用户名或密码错误'), findsOneWidget);
  });
}
