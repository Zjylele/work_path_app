/// 轨迹点模型：对应 track_point 表
class TrackPoint {
  const TrackPoint({
    required this.id,
    required this.trackId,
    required this.latitude,
    required this.longitude,
    required this.recordTime,
  });

  /// 主键（UUID）
  final String id;

  /// 所属轨迹 id
  final String trackId;

  /// 纬度（WGS-84，采集原始值）
  final double latitude;

  /// 经度（WGS-84，采集原始值）
  final double longitude;

  /// 记录时间
  final DateTime recordTime;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'track_id': trackId,
      'latitude': latitude,
      'longitude': longitude,
      'record_time': recordTime.toIso8601String(),
    };
  }

  factory TrackPoint.fromMap(Map<String, Object?> map) {
    return TrackPoint(
      id: map['id'] as String,
      trackId: map['track_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      recordTime: DateTime.parse(map['record_time'] as String),
    );
  }

  TrackPoint copyWith({
    String? id,
    String? trackId,
    double? latitude,
    double? longitude,
    DateTime? recordTime,
  }) {
    return TrackPoint(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      recordTime: recordTime ?? this.recordTime,
    );
  }
}
