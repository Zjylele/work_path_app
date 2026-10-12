/// 工作事件模型：对应后端 work_event 表（员工侧精简视图）
///
/// 一条轨迹经过清洗去噪、停留点识别与语义标注后，会产出 0~N 条工作事件：
/// MOVE=移动、STAY=停留。只有停留事件带停留时长、地点名称与语义标签，
/// 也正是轨迹详情页要展示的「语义标注结果」。
///
/// 后端接口：GET /api/track/{id}/events
class WorkEvent {
  const WorkEvent({
    required this.eventId,
    this.eventType,
    this.startTime,
    this.endTime,
    this.centerLat,
    this.centerLng,
    this.dwellSeconds,
    this.poiName,
    this.semanticLabel,
    this.confidence,
    this.aiReason,
    this.confirmStatus = 0,
  });

  /// 事件ID
  final int eventId;

  /// 事件类型：MOVE 移动 / STAY 停留
  final String? eventType;

  final DateTime? startTime;

  final DateTime? endTime;

  /// 停留点质心纬度
  final double? centerLat;

  /// 停留点质心经度
  final double? centerLng;

  /// 停留时长（秒）
  final int? dwellSeconds;

  /// 地点名称（逆地理编码失败时为 null）
  final String? poiName;

  /// 语义标注，如 客户拜访 / 用餐
  final String? semanticLabel;

  /// 标注置信度 0-1
  final double? confidence;

  /// 模型给出的判定理由
  final String? aiReason;

  /// 复核状态：0=待确认 1=已确认 2=已驳回
  final int confirmStatus;

  /// 是否停留事件——只有停留才谈得上语义标注
  bool get isStay => eventType == 'STAY';

  /// 语义标签，缺失时给一句可读的兜底，避免界面上出现空白
  String get labelText {
    final label = semanticLabel;
    return (label != null && label.isNotEmpty) ? label : '未标注';
  }

  /// 置信度百分比；没有置信度时返回 null，由调用方决定是否显示
  String? get confidenceText {
    final c = confidence;
    return c == null ? null : '${(c * 100).round()}%';
  }

  /// 停留时长文案；不足 1 分钟按秒显示
  String? get dwellText {
    final s = dwellSeconds;
    if (s == null || s <= 0) return null;
    if (s < 60) return '$s 秒';
    final minutes = s ~/ 60;
    final rest = s % 60;
    return rest == 0 ? '$minutes 分钟' : '$minutes 分 $rest 秒';
  }

  /// 复核状态中文名
  String get confirmText => switch (confirmStatus) {
    0 => '待确认',
    1 => '已确认',
    2 => '已驳回',
    _ => '未知',
  };

  factory WorkEvent.fromJson(Map<String, dynamic> json) {
    return WorkEvent(
      eventId: (json['eventId'] as num?)?.toInt() ?? 0,
      eventType: json['eventType'] as String?,
      startTime: _parseTime(json['startTime']),
      endTime: _parseTime(json['endTime']),
      centerLat: (json['centerLat'] as num?)?.toDouble(),
      centerLng: (json['centerLng'] as num?)?.toDouble(),
      dwellSeconds: (json['dwellSeconds'] as num?)?.toInt(),
      poiName: json['poiName'] as String?,
      semanticLabel: json['semanticLabel'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      aiReason: json['aiReason'] as String?,
      confirmStatus: (json['confirmStatus'] as num?)?.toInt() ?? 0,
    );
  }

  /// 后端时间格式为 yyyy-MM-dd HH:mm:ss（Jackson 全局配置），
  /// DateTime.parse 只认 ISO8601，所以把空格换成 T。
  static DateTime? _parseTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
}
