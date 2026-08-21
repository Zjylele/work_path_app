import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/track.dart';
import '../models/track_point.dart';
import '../services/track_database.dart';

/// 轨迹记录页
///
/// 流程：检查定位权限 → 点击「开始记录」定时采点（默认每 5 秒一个点）
/// → 点击「结束并保存」生成 Track + TrackPoint 写入 sqflite 后返回。
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

  /// 每秒刷新 UI（更新时间显示与按间隔采点）
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  /// 开始记录：启动定时器，立即采第一个点
  void _startRecording() {
    setState(() {
      _recording = true;
      _startTime = DateTime.now();
      _lastSampleTime = _startTime;
      _points.clear();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final now = DateTime.now();
      // 每达到采集间隔采一个点
      if (now.difference(_lastSampleTime!) >= _sampleInterval) {
        _lastSampleTime = now;
        await _capturePoint();
      }
      if (mounted) setState(() {});
    });

    _capturePoint();
  }

  /// 采集一个位置点
  Future<void> _capturePoint() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      _points.add(
        TrackPoint(
          id: _uuid.v4(),
          trackId: '',
          latitude: pos.latitude,
          longitude: pos.longitude,
          recordTime: DateTime.now(),
        ),
      );
    } catch (_) {
      // 单次定位失败忽略，等下一个周期重试
    }
  }

  /// 结束记录：停止采点，生成轨迹并入库，返回上一页
  Future<void> _stopRecording() async {
    _timer?.cancel();
    _timer = null;

    final endTime = DateTime.now();
    final trackId = _uuid.v4();
    final track = Track(
      id: trackId,
      userId: widget.username,
      startTime: _startTime ?? endTime,
      endTime: endTime,
      status: 'finished',
    );

    // 为每个点补上 trackId
    final points = _points
        .map((p) => p.copyWith(trackId: trackId))
        .toList();

    await TrackDatabase.instance.insertTrack(track);
    await TrackDatabase.instance.insertTrackPoints(points);

    if (!mounted) return;
    _showSnack('轨迹已保存，共采集 ${points.length} 个点');
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('记录工作轨迹'),
        backgroundColor: const Color(0xFFF5F5F5),
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
                    color: _recording ? const Color(0xFFE8F0FE) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF73ACF6), width: 2),
                  ),
                  child: Icon(
                    _recording ? Icons.gps_fixed : Icons.place_outlined,
                    size: 44,
                    color: const Color(0xFF73ACF6),
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
                            style: TextStyle(fontSize: 17, color: Colors.white),
                          ),
                        )
                      : FilledButton(
                          onPressed:
                              _permissionGranted ? _startRecording : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF73ACF6),
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            '开始记录',
                            style: TextStyle(fontSize: 17, color: Colors.white),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
