// 登录页与启动登录态检查的冒烟测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:work_path_test/main.dart';
import 'package:work_path_test/pages/home_page.dart';
import 'package:work_path_test/pages/login_page.dart';
import 'package:work_path_test/services/auth_service.dart';
import 'package:work_path_test/services/track_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // 首页会访问数据库，注入 FFI factory（内存库）
    TrackDatabase.instance.factoryOverride = databaseFactoryFfi;
    TrackDatabase.instance.pathOverride = inMemoryDatabasePath;
    await TrackDatabase.instance.close();
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
      'logged_in': true,
      'logged_in_username': 'admin',
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
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('登录'));
    await tester.pump();

    // 仍停留在登录页，并显示失败提示
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('登录失败，用户名或密码错误'), findsOneWidget);
  });
}
