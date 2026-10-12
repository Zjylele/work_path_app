// 工作事件模型单测：解析后端 JSON、时间格式与展示文案。
//
// 后端 /api/track/{id}/events 的时间是 yyyy-MM-dd HH:mm:ss（空格分隔），
// DateTime.parse 只认 ISO8601——这里锁住这个转换，避免详情页静默丢时间。
import 'package:flutter_test/flutter_test.dart';

import 'package:work_path_test/models/work_event.dart';

void main() {
  test('解析停留事件：标签、置信度、停留时长与时间', () {
    final event = WorkEvent.fromJson({
      'eventId': 11,
      'eventType': 'STAY',
      'startTime': '2026-10-04 08:30:00',
      'endTime': '2026-10-04 08:36:45',
      'dwellSeconds': 405,
      'poiName': '武侯区恒大珺临阁',
      'semanticLabel': '驻点办公',
      'confidence': 0.5,
      'aiReason': '停留时长超过阈值',
      'confirmStatus': 0,
    });

    expect(event.isStay, isTrue);
    expect(event.labelText, '驻点办公');
    expect(event.confidenceText, '50%');
    expect(event.dwellText, '6 分 45 秒');
    expect(event.poiName, '武侯区恒大珺临阁');
    expect(event.confirmText, '待确认');
    expect(event.startTime, DateTime(2026, 10, 4, 8, 30));
    expect(event.endTime, DateTime(2026, 10, 4, 8, 36, 45));
  });

  test('缺失字段不炸：标签兜底、置信度与停留时长为空、状态默认待确认', () {
    final event = WorkEvent.fromJson({'eventId': 3, 'eventType': 'MOVE'});

    expect(event.isStay, isFalse);
    expect(event.labelText, '未标注');
    expect(event.confidenceText, isNull);
    expect(event.dwellText, isNull);
    expect(event.startTime, isNull);
    expect(event.confirmStatus, 0);
  });

  test('停留时长不足一分钟按秒显示，整分钟不带零秒', () {
    expect(
      WorkEvent.fromJson({'eventId': 1, 'dwellSeconds': 45}).dwellText,
      '45 秒',
    );
    expect(
      WorkEvent.fromJson({'eventId': 2, 'dwellSeconds': 300}).dwellText,
      '5 分钟',
    );
  });

  test('已确认与已驳回的文案', () {
    expect(
      WorkEvent.fromJson({'eventId': 1, 'confirmStatus': 1}).confirmText,
      '已确认',
    );
    expect(
      WorkEvent.fromJson({'eventId': 2, 'confirmStatus': 2}).confirmText,
      '已驳回',
    );
  });
}
