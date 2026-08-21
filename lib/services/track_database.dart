import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/track.dart';
import '../models/track_point.dart';

/// 轨迹数据库服务（sqflite）
///
/// 包含两张表：
/// - track：轨迹主表（id、user_id、start_time、end_time、status、distance）
/// - track_point：轨迹点表（id、track_id、latitude、longitude、record_time）
///
/// 单例使用：[TrackDatabase.instance]
class TrackDatabase {
  TrackDatabase._();

  static final TrackDatabase instance = TrackDatabase._();

  /// 测试时可注入自定义 factory（如 sqflite_common_ffi 的 databaseFactoryFfi）
  DatabaseFactory? factoryOverride;

  /// 测试时可指定数据库路径（如 ':memory:'）
  String? pathOverride;

  Database? _db;

  /// 关闭并重置数据库连接（测试中用于隔离用例）
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final factory = factoryOverride ?? databaseFactory;
    final dbPath = pathOverride ?? join(await getDatabasesPath(), 'work_track.db');
    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          // 开启外键约束，支持级联删除
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      ),
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE track (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        status TEXT NOT NULL DEFAULT 'ongoing',
        distance REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE track_point (
        id TEXT PRIMARY KEY,
        track_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        record_time TEXT NOT NULL,
        FOREIGN KEY (track_id) REFERENCES track (id) ON DELETE CASCADE
      )
    ''');
    // 按开始时间倒序查询轨迹
    await db.execute(
      'CREATE INDEX idx_track_start_time ON track (start_time DESC)',
    );
    // 按轨迹 id + 记录时间查询轨迹点
    await db.execute(
      'CREATE INDEX idx_track_point_track ON track_point (track_id, record_time ASC)',
    );
  }

  // ==================== Track 增删改查 ====================

  /// 插入一条轨迹，返回其 id
  Future<String> insertTrack(Track track) async {
    final db = await database;
    await db.insert('track', track.toMap());
    return track.id;
  }

  /// 按开始时间倒序查询轨迹列表（可按员工过滤、限制条数）
  Future<List<Track>> getTracks({String? userId, int? limit}) async {
    final db = await database;
    final where = userId == null ? null : 'user_id = ?';
    final whereArgs = userId == null ? null : [userId];
    final rows = await db.query(
      'track',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return rows.map(Track.fromMap).toList();
  }

  /// 按 id 查询单条轨迹
  Future<Track?> getTrack(String id) async {
    final db = await database;
    final rows = await db.query('track', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Track.fromMap(rows.first);
  }

  /// 更新轨迹，返回受影响行数
  Future<int> updateTrack(Track track) async {
    final db = await database;
    return db.update('track', track.toMap(), where: 'id = ?', whereArgs: [track.id]);
  }

  /// 删除轨迹（级联删除其轨迹点），返回受影响行数
  Future<int> deleteTrack(String id) async {
    final db = await database;
    return db.delete('track', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== TrackPoint 增删改查 ====================

  /// 批量插入轨迹点
  Future<void> insertTrackPoints(List<TrackPoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final point in points) {
      batch.insert('track_point', point.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// 按记录时间升序查询某条轨迹的所有点
  Future<List<TrackPoint>> getTrackPoints(String trackId) async {
    final db = await database;
    final rows = await db.query(
      'track_point',
      where: 'track_id = ?',
      whereArgs: [trackId],
      orderBy: 'record_time ASC',
    );
    return rows.map(TrackPoint.fromMap).toList();
  }

  /// 删除某条轨迹的所有点，返回受影响行数
  Future<int> deleteTrackPoints(String trackId) async {
    final db = await database;
    return db.delete(
      'track_point',
      where: 'track_id = ?',
      whereArgs: [trackId],
    );
  }
}
