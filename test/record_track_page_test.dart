// 记录页轻量 widget 测试：验证「开始记录前显示轨迹名称输入框与开始按钮」。
//
// 定位权限检查依赖平台通道，在测试环境异步抛 MissingPluginException——
// 用 takeException 消费（它只影响权限状态，不影响本测试要断言的渲染）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:work_path_test/pages/record_track_page.dart';

void main() {
  testWidgets('记录页在开始前显示轨迹名称输入框', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RecordTrackPage(username: 'admin')),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // 消费平台通道缺失导致的异步异常（测试环境无 geolocator 插件）
    while (tester.takeException() != null) {}

    expect(find.text('轨迹名称'), findsOneWidget);
    expect(find.text('开始记录'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
