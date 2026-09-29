/// 轨迹模型：对应 track 表
class Track {
  const Track({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.status = 'ongoing',
    this.distance,
    this.uploadStatus = 0,
  });

  /// 主键（UUID）
  final String id;

  /// 所属员工账号/手机号
  final String userId;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间（进行中为 null）
  final DateTime? endTime;

  /// 状态：ongoing 进行中 / finished 已完成
  final String status;

  /// 总里程（米，可选）
  final double? distance;

  /// 上传状态：0=待上传 / 1=已上传 / 2=上传失败
  final int uploadStatus;

  /// 是否已完成
  bool get isFinished => status == 'finished';

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status,
      'distance': distance,
      'upload_status': uploadStatus,
    };
  }

  factory Track.fromMap(Map<String, Object?> map) {
    return Track(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] == null
          ? null
          : DateTime.parse(map['end_time'] as String),
      status: (map['status'] as String?) ?? 'ongoing',
      distance: (map['distance'] as num?)?.toDouble(),
      uploadStatus: (map['upload_status'] as num?)?.toInt() ?? 0,
    );
  }

  Track copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    double? distance,
    int? uploadStatus,
    bool clearEndTime = false,
  }) {
    return Track(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      status: status ?? this.status,
      distance: distance ?? this.distance,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }
}
