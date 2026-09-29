// TrackDatabase 的 CRUD 单元测试。
// 使用 sqflite_common_ffi 在桌面环境运行 SQLite（内存库，不落盘）。

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:work_path_test/models/track.dart';
import 'package:work_path_test/models/track_point.dart';
import 'package:work_path_test/services/track_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // 注入 FFI factory，使用内存数据库，每个用例独立
    TrackDatabase.instance.factoryOverride = databaseFactoryFfi;
    TrackDatabase.instance.pathOverride = inMemoryDatabasePath;
    // 重置数据库连接，确保用例之间数据隔离
    await TrackDatabase.instance.close();
  });

  test('插入轨迹后可以按 id 查询', () async {
    final db = TrackDatabase.instance;
    final track = Track(
      id: 'track-1',
      userId: 'admin',
      startTime: DateTime(2026, 8, 19, 9),
      endTime: DateTime(2026, 8, 19, 10),
      status: 'finished',
      distance: 1200,
    );

    final id = await db.insertTrack(track);
    expect(id, 'track-1');

    final fetched = await db.getTrack('track-1');
    expect(fetched, isNotNull);
    expect(fetched!.userId, 'admin');
    expect(fetched.startTime, DateTime(2026, 8, 19, 9));
    expect(fetched.endTime, DateTime(2026, 8, 19, 10));
    expect(fetched.status, 'finished');
    expect(fetched.distance, 1200);
    expect(fetched.isFinished, isTrue);
  });

  test('查询不存在的轨迹返回 null', () async {
    final db = TrackDatabase.instance;
    expect(await db.getTrack('not-exist'), isNull);
  });

  test('查询轨迹列表按开始时间倒序', () async {
    final db = TrackDatabase.instance;
    await db.insertTrack(
      Track(id: 't1', userId: 'admin', startTime: DateTime(2026, 8, 18, 8)),
    );
    await db.insertTrack(
      Track(id: 't2', userId: 'admin', startTime: DateTime(2026, 8, 19, 8)),
    );
    await db.insertTrack(
      Track(id: 't3', userId: 'bob', startTime: DateTime(2026, 8, 17, 8)),
    );

    final all = await db.getTracks();
    expect(all.map((t) => t.id).toList(), ['t2', 't1', 't3']);

    final adminOnly = await db.getTracks(userId: 'admin');
    expect(adminOnly.map((t) => t.id).toList(), ['t2', 't1']);

    final limited = await db.getTracks(limit: 1);
    expect(limited.map((t) => t.id).toList(), ['t2']);
  });

  test('更新轨迹字段生效', () async {
    final db = TrackDatabase.instance;
    await db.insertTrack(
      Track(id: 't1', userId: 'admin', startTime: DateTime(2026, 8, 19, 9)),
    );

    final updated = Track(
      id: 't1',
      userId: 'admin',
      startTime: DateTime(2026, 8, 19, 9),
      endTime: DateTime(2026, 8, 19, 12),
      status: 'finished',
      distance: 5000,
    );
    final affected = await db.updateTrack(updated);
    expect(affected, 1);

    final fetched = await db.getTrack('t1');
    expect(fetched!.status, 'finished');
    expect(fetched.endTime, DateTime(2026, 8, 19, 12));
    expect(fetched.distance, 5000);
  });

  test('轨迹点按记录时间升序查询', () async {
    final db = TrackDatabase.instance;
    await db.insertTrack(
      Track(id: 't1', userId: 'admin', startTime: DateTime(2026, 8, 19, 9)),
    );

    await db.insertTrackPoints([
      TrackPoint(
        id: 'p1',
        trackId: 't1',
        latitude: 39.90,
        longitude: 116.40,
        recordTime: DateTime(2026, 8, 19, 9, 0, 5),
      ),
      TrackPoint(
        id: 'p2',
        trackId: 't1',
        latitude: 39.91,
        longitude: 116.41,
        recordTime: DateTime(2026, 8, 19, 9, 0, 10),
      ),
      TrackPoint(
        id: 'p3',
        trackId: 't1',
        latitude: 39.92,
        longitude: 116.42,
        recordTime: DateTime(2026, 8, 19, 9, 0, 0),
      ),
    ]);

    final points = await db.getTrackPoints('t1');
    expect(points.map((p) => p.id).toList(), ['p3', 'p1', 'p2']);
    expect(points.first.latitude, 39.92);
  });

  test('删除轨迹级联删除其轨迹点', () async {
    final db = TrackDatabase.instance;
    await db.insertTrack(
      Track(id: 't1', userId: 'admin', startTime: DateTime(2026, 8, 19, 9)),
    );
    await db.insertTrackPoints([
      TrackPoint(
        id: 'p1',
        trackId: 't1',
        latitude: 39.9,
        longitude: 116.4,
        recordTime: DateTime(2026, 8, 19, 9, 0, 0),
      ),
      TrackPoint(
        id: 'p2',
        trackId: 't1',
        latitude: 39.91,
        longitude: 116.41,
        recordTime: DateTime(2026, 8, 19, 9, 0, 5),
      ),
    ]);

    expect(await db.getTrackPoints('t1'), hasLength(2));

    final affected = await db.deleteTrack('t1');
    expect(affected, 1);
    expect(await db.getTrack('t1'), isNull);
    // 外键级联删除轨迹点
    expect(await db.getTrackPoints('t1'), isEmpty);
  });

  test('新轨迹默认待上传，upload_status 可更新', () async {
    final db = TrackDatabase.instance;
    await db.insertTrack(
      Track(id: 't1', userId: 'admin', startTime: DateTime(2026, 8, 19, 9)),
    );
    expect((await db.getTrack('t1'))!.uploadStatus, 0);

    await db.updateUploadStatus('t1', 2);
    expect((await db.getTrack('t1'))!.uploadStatus, 2);

    await db.updateUploadStatus('t1', 1);
    expect((await db.getTrack('t1'))!.uploadStatus, 1);
  });

  test('getUnuploadedTracks 只返回已完成且未上传的轨迹', () async {
    final db = TrackDatabase.instance;
    // 已完成、待上传
    await db.insertTrack(
      Track(
        id: 't1',
        userId: 'admin',
        startTime: DateTime(2026, 8, 19, 8),
        status: 'finished',
      ),
    );
    // 已完成、上传失败
    await db.insertTrack(
      Track(
        id: 't2',
        userId: 'admin',
        startTime: DateTime(2026, 8, 19, 9),
        status: 'finished',
        uploadStatus: 2,
      ),
    );
    // 已完成、已上传 → 不应出现
    await db.insertTrack(
      Track(
        id: 't3',
        userId: 'admin',
        startTime: DateTime(2026, 8, 19, 10),
        status: 'finished',
        uploadStatus: 1,
      ),
    );
    // 进行中 → 不应出现
    await db.insertTrack(
      Track(
        id: 't4',
        userId: 'admin',
        startTime: DateTime(2026, 8, 19, 11),
        status: 'ongoing',
      ),
    );

    final pending = await db.getUnuploadedTracks();
    expect(pending.map((t) => t.id).toList(), ['t1', 't2']);
  });
}
