import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:work_path_test/models/track.dart';
import 'package:work_path_test/pages/home_page.dart';
import 'package:work_path_test/services/track_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    TrackDatabase.instance.factoryOverride = databaseFactoryFfi;
    TrackDatabase.instance.pathOverride = inMemoryDatabasePath;
    await TrackDatabase.instance.close();
  });
  tearDown(() => TrackDatabase.instance.close());

  testWidgets('今日统计包含三条以外的轨迹，排除其他用户及昨日记录', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 1);
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        final start = i == 5 ? today.subtract(const Duration(days: 1)) : today;
        await TrackDatabase.instance.insertTrack(
          Track(
            id: 'home-$i',
            userId: i == 4 ? 'other' : 'worker',
            name: '巡检-$i',
            startTime: start,
            endTime: start.add(const Duration(hours: 1)),
            distance: 1000,
            status: 'finished',
          ),
        );
      }
    });
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(username: 'worker')),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.text('正在加载轨迹…').evaluate().isEmpty) break;
      }
    });
    expect(find.text('4.0 km', findRichText: true), findsOneWidget);
    expect(find.text('4.0 小时', findRichText: true), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏及大字号下首页保持可用，匿名不查询其他用户轨迹', (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('开始记录工作轨迹'), findsOneWidget);
    expect(find.text('暂无轨迹，开始记录你的第一段工作路线'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
