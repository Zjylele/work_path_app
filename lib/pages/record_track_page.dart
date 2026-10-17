import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/track.dart';
import '../models/track_point.dart';
import '../services/track_database.dart';
import '../services/track_upload_service.dart';

/// 轨迹记录页
///
/// 流程：检查定位权限 → 点击「开始记录」持续监听定位（每 5 秒采一个点）
/// → 点击「结束并保存」生成 Track + TrackPoint 写入 sqflite 后返回。
///
/// 后台采集说明：通过 geolocator 的 [ForegroundNotificationConfig] 在 Android
/// 上启动「定位类型」前台服务 + 常驻通知，熄屏后应用仍按前台运行，位置流
/// 不会被 Doze 冻结；再配合 WAKE_LOCK 保持 CPU 唤醒（Manifest 已声明权限）。
/// iOS 需在 Info.plist 配置 UIBackgroundModes=location 才能在后台持续定位。
class RecordTrackPage extends StatefulWidget {
  const RecordTrackPage({super.key, required this.username});

  /// 当前登录员工账号
  final String username;

  @override
  State<RecordTrackPage> createState() => _RecordTrackPageState();
}

class _RecordTrackPageState extends State<RecordTrackPage> {
  /// 采集间隔
  static const _sampleInterval = Duration(seconds: 5);

  final _uuid = const Uuid();

  /// 是否已授权定位
  bool _permissionGranted = false;

  /// 是否正在记录
  bool _recording = false;

  /// 开始记录时间
  DateTime? _startTime;

  /// 上一次采点时间
  DateTime? _lastSampleTime;

  /// 已采集的轨迹点（记录中的点，trackId 暂为空串）
  final List<TrackPoint> _points = [];

  /// 轨迹名称输入框（开始记录前填写）
  final TextEditingController _nameController = TextEditingController();

  /// 本次记录的轨迹名称（开始时锁定，结束时随轨迹保存并上传）
  String? _trackName;

  /// 位置流订阅（替代 Timer 轮询，熄屏时由前台服务保持运行）
  StreamSubscription<Position>? _positionSub;

  /// 上一次成功采集的位置（用于相同/漂移点去重）
  Position? _lastAddedPos;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  /// 检查并申请定位权限
  Future<void> _checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('定位服务未开启，请在系统设置中打开定位');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showSnack('定位权限被拒绝，无法记录轨迹');
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnack('定位权限被永久拒绝，请在系统设置中开启');
      return;
    }

    // Android 10+ 仅授权「使用期间允许」时，熄屏后台定位会被系统限制，
    // 需要用户到系统设置中手动改为「始终允许」
    if (permission == LocationPermission.whileInUse) {
      _showSnack('建议将定位权限设为「始终允许」，否则熄屏后可能无法持续采集');
    }

    if (mounted) {
      setState(() => _permissionGranted = true);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 开始记录：校验名称 → 订阅位置流，按采集间隔持续采点
  void _startRecording() {
    // 名称在开始时填入并锁定，结束上传时随轨迹一并入库
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('请先填写本次轨迹名称');
      return;
    }
    setState(() {
      _recording = true;
      _trackName = name;
      _startTime = DateTime.now();
      _lastSampleTime = _startTime;
      _points.clear();
      _lastAddedPos = null;
    });

    _positionSub =
        Geolocator.getPositionStream(locationSettings: _locationSettings())
            .listen(
              (pos) {
                final now = DateTime.now();
                // 按采集间隔过滤，并过滤掉过期缓存定位 / 原地重复点位
                if (now.difference(_lastSampleTime!) >= _sampleInterval &&
                    _isUsablePosition(pos)) {
                  _lastSampleTime = now;
                  _lastAddedPos = pos;
                  _addPoint(pos);
                }
                if (mounted) setState(() {});
              },
              onError: (_) {
                // 单次定位失败忽略，等待下一条位置更新
              },
            );
  }

  /// 位置是否可用于采集：
  /// 1. 时间戳过旧（>30s）的定位视为缓存/过期值丢弃，避免网络差时
  ///    首条回调是 lastKnownPosition（旧位置）污染轨迹起点；
  /// 2. 与上一点距离过近（<5m）视为原地重复或漂移，跳过避免冗余点。
  bool _isUsablePosition(Position pos) {
    // geolocator 的 timestamp 非空，过旧的定位视为缓存/过期值丢弃
    if (DateTime.now().difference(pos.timestamp).abs() >
        const Duration(seconds: 30)) {
      return false;
    }
    if (_lastAddedPos != null) {
      final d = _distanceMeters(
        _lastAddedPos!.latitude,
        _lastAddedPos!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (d < 5) return false;
    }
    return true;
  }

  /// 两坐标点间的球面距离（米）
  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final p1 = lat1 * pi / 180;
    final p2 = lat2 * pi / 180;
    final dp = (lat2 - lat1) * pi / 180;
    final dl = (lng2 - lng1) * pi / 180;
    final a =
        sin(dp / 2) * sin(dp / 2) +
        cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// 位置流参数：
  /// - Android：通过 [ForegroundNotificationConfig] 启动前台服务 + 常驻通知，
  ///   熄屏时位置流持续回调，不被 Doze 冻结
  /// - 其他平台（iOS/桌面）：使用默认前台定位
  LocationSettings _locationSettings() {
    if (!Platform.isAndroid) {
      return const LocationSettings(accuracy: LocationAccuracy.high);
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: '正在记录工作轨迹',
        notificationText: '轨迹采集中，保持后台运行',
        notificationChannelName: '轨迹记录',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  /// 记录一个位置点
  void _addPoint(Position pos) {
    _points.add(
      TrackPoint(
        id: _uuid.v4(),
        trackId: '',
        latitude: pos.latitude,
        longitude: pos.longitude,
        recordTime: DateTime.now(),
      ),
    );
  }

  /// 结束记录：确认后保存轨迹并返回上一页
  Future<void> _stopRecording() async {
    // 结束前二次确认，防止误触
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束本次记录？'),
        content: Text('已采集 ${_points.length} 个点，结束后将保存并上传。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续记录'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('结束并保存'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _finishAndSave();
  }

  /// 记录中点击返回：询问是否退出，是则保存本次轨迹并上传，否则留在页面
  Future<void> _confirmExitWhileRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('轨迹正在记录中'),
        content: Text('当前已采集 ${_points.length} 个点。退出将保存本次轨迹并上传，确定退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续记录'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存并退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _finishAndSave();
  }

  /// 停止采点 → 生成轨迹入库 → 上传后端 → 返回上一页
  Future<void> _finishAndSave() async {
    await _positionSub?.cancel();
    _positionSub = null;

    final endTime = DateTime.now();
    final trackId = _uuid.v4();
    final track = Track(
      id: trackId,
      userId: widget.username,
      name: _trackName,
      startTime: _startTime ?? endTime,
      endTime: endTime,
      status: 'finished',
    );

    // 为每个点补上 trackId
    final points = _points.map((p) => p.copyWith(trackId: trackId)).toList();

    await TrackDatabase.instance.insertTrack(track);
    await TrackDatabase.instance.insertTrackPoints(points);

    // 结束轨迹后自动上传到后端；失败由补传机制（启动/手动重试）兜底
    TrackUploadService.instance.uploadTrack(track).catchError((_) {});

    if (!mounted) return;
    _showSnack('「$_trackName」已保存，共采集 ${points.length} 个点');
    Navigator.of(context).pop(true);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _recording && _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    return PopScope(
      // 记录中拦截系统返回/返回键，防止误触丢失轨迹；未记录时正常返回
      canPop: !_recording,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitWhileRecording();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text('记录工作轨迹'),
          backgroundColor: const Color(0xFFF7F8FA),
          foregroundColor: Colors.black,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 状态图标
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: _recording
                          ? const Color(0xFFE8F0FE)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4B5969),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _recording ? Icons.gps_fixed : Icons.place_outlined,
                      size: 44,
                      color: const Color(0xFF4B5969),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 状态文案
                  Text(
                    _recording
                        ? '记录中…'
                        : (_permissionGranted ? '准备就绪' : '正在检查定位权限…'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _recording
                        ? '已记录 ${_formatDuration(duration)} · 采集 ${_points.length} 个点'
                        : '点击下方按钮开始记录工作轨迹',
                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 40),
                  // 未开始记录时先填名称（开始后收起，名称随本次记录锁定）
                  if (!_recording) ...[
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _nameController,
                        maxLength: 100,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: '轨迹名称',
                          hintText: '如：客户拜访行程',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // 开始/结束按钮
                  SizedBox(
                    width: 240,
                    height: 52,
                    child: _recording
                        ? FilledButton(
                            onPressed: _stopRecording,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              '结束并保存',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : FilledButton(
                            onPressed: _permissionGranted
                                ? _startRecording
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4B5969),
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              '开始记录',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
