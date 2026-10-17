import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_path_test/widgets/track_detail_layout.dart';

void main() {
  testWidgets('详情面板可以展开、连续滚动到底部，再收起查看地图', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackDetailLayout(
            map: const ColoredBox(color: Colors.white),
            summary: const SizedBox(height: 180, child: Text('轨迹信息')),
            events: const SizedBox(height: 300, child: Text('语义标注')),
            pointCount: 20,
            pointBuilder: (_, index) =>
                SizedBox(height: 60, child: Text('坐标点 $index')),
          ),
        ),
      ),
    );
    final scroll = find.byType(CustomScrollView);
    final initial = tester.getSize(scroll).height;
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getSize(scroll).height, greaterThan(initial));
    await tester.scrollUntilVisible(
      find.text('坐标点 19'),
      400,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('坐标点 19'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.drag(scroll, const Offset(0, 700));
      await tester.pumpAndSettle();
    }
    expect(tester.getSize(scroll).height, lessThan(initial));
    expect(tester.takeException(), isNull);
  });

  testWidgets('横屏和大字号下详情不溢出，地图保留拖动区域', (tester) async {
    tester.view.physicalSize = const Size(740, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var mapDragged = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: TrackDetailLayout(
            map: GestureDetector(
              onPanUpdate: (_) => mapDragged = true,
              child: const ColoredBox(color: Colors.white),
            ),
            summary: const Text('轨迹信息'),
            pointCount: 0,
            pointBuilder: (_, index) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.dragFrom(const Offset(100, 50), const Offset(100, 10));
    await tester.pumpAndSettle();
    expect(mapDragged, isTrue);
    expect(tester.takeException(), isNull);
  });
}
