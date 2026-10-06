/// 整改工单模型：对应后端 rectification_order 表
///
/// 状态机（后端 RectificationOrderService）：
/// ```
///   0 待处理 --员工提交处理说明--> 1 处理中 --管理员确认整改--> 2 已闭环
///   0 待处理 --员工申诉---------> 3 申诉中 --管理员复核-------> 2 已闭环
/// ```
/// 员工侧只有「提交处理说明」与「申诉」两个动作，闭环一律由管理员触发——
/// 这是「员工有申辩渠道，但结论严肃性不被架空」的平衡。
class RectificationOrder {
  const RectificationOrder({
    required this.orderId,
    required this.userId,
    required this.content,
    required this.status,
    this.assignTime,
    this.handleNote,
    this.handleTime,
    this.appealReason,
    this.reviewNote,
    this.closeTime,
    this.createTime,
  });

  /// 工单ID
  final int orderId;

  /// 责任员工ID
  final int userId;

  /// 整改内容
  final String content;

  /// 状态：0=待处理 1=处理中 2=已闭环 3=申诉中
  final int status;

  /// 下发时间
  final DateTime? assignTime;

  /// 员工处理说明（0→1 时提交）
  final String? handleNote;

  /// 提交处理说明的时间
  final DateTime? handleTime;

  /// 申诉理由（0→3 时提交）
  final String? appealReason;

  /// 管理员复核意见
  final String? reviewNote;

  /// 闭环时间
  final DateTime? closeTime;

  final DateTime? createTime;

  /// 员工可否操作：只有「待处理」能提交处理说明或申诉
  bool get canAct => status == 0;

  /// 状态中文名
  String get statusText => switch (status) {
        0 => '待处理',
        1 => '处理中',
        2 => '已闭环',
        3 => '申诉中',
        _ => '未知',
      };

  factory RectificationOrder.fromJson(Map<String, dynamic> json) {
    return RectificationOrder(
      orderId: (json['orderId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      content: (json['content'] as String?) ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      assignTime: _parseTime(json['assignTime']),
      handleNote: json['handleNote'] as String?,
      handleTime: _parseTime(json['handleTime']),
      appealReason: json['appealReason'] as String?,
      reviewNote: json['reviewNote'] as String?,
      closeTime: _parseTime(json['closeTime']),
      createTime: _parseTime(json['createTime']),
    );
  }

  /// 后端时间格式为 yyyy-MM-dd HH:mm:ss（Jackson 全局配置），
  /// DateTime.parse 只认 ISO8601，所以把空格换成 T。
  static DateTime? _parseTime(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
}
