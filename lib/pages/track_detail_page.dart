import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/track.dart';
import '../models/track_point.dart';
import '../models/work_event.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/track_database.dart';
import '../utils/geo_convert.dart';

/// 轨迹详情页：高德地图渲染轨迹路径 + 起终点实心圆 + 语义标注 + 坐标点列表
class TrackDetailPage extends StatefulWidget {
  const TrackDetailPage({super.key, required this.track, this.serverTrackId});

  final Track track;

  /// 服务端轨迹 id。本地只存 UUID，语义标注要从服务端按 id 取；
  /// 拿不到时（还没上传成功、或列表没拉到）为 null，此时不显示语义标注。
  final int? serverTrackId;

  @override
  State<TrackDetailPage> createState() => _TrackDetailPageState();
}

class _TrackDetailPageState extends State<TrackDetailPage> {
  List<TrackPoint> _points = [];

  /// 转换到 GCJ-02 后的地图坐标
  List<LatLng> _latLngs = [];

  /// 起终点 Marker（实心圆）
  Set<Marker> _markers = const {};

  /// 蓝色路径
  Set<Polyline> _polylines = const {};

  /// 是否已加载完成（至少有一个点才显示地图）
  bool _mapReady = false;

  /// 该轨迹的语义标注结果（服务端返回的停留事件）
  List<WorkEvent> _events = [];

  /// 语义标注是否已成功拉到；只有拉到了才谈得上「没有结果」的提示
  bool _eventsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _loadEvents();
  }

  Future<void> _loadPoints() async {
    final points = await TrackDatabase.instance.getTrackPoints(widget.track.id);

    if (points.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    // WGS-84 → GCJ-02 坐标转换（高德地图坐标系）
    final latLngs = points.map((p) {
      final g = GeoConvert.wgs84ToGcj02(p.latitude, p.longitude);
      return LatLng(g.lat, g.lng);
    }).toList();

    // 生成起终点实心圆图标
    final startIcon = BitmapDescriptor.fromBytes(
      await _createCircleIcon(Colors.green),
    );
    final endIcon = BitmapDescriptor.fromBytes(
      await _createCircleIcon(Colors.red),
    );

    if (!mounted) return;
    setState(() {
      _points = points;
      _latLngs = latLngs;
      _markers = {
        Marker(
          position: latLngs.first,
          icon: startIcon,
          anchor: const Offset(0.5, 0.5),
          infoWindowEnable: false,
        ),
        Marker(
          position: latLngs.last,
          icon: endIcon,
          anchor: const Offset(0.5, 0.5),
          infoWindowEnable: false,
        ),
      };
      _polylines = {
        Polyline(
          points: latLngs,
          color: Colors.blue,
          width: 6,
          capType: CapType.round,
          joinType: JoinType.round,
        ),
      };
      _mapReady = true;
    });
  }

  /// 拉这条轨迹的语义标注结果（员工侧接口）。
  ///
  /// 属于增强信息：没登录、没上传成功、网络不通，都只是不显示，
  /// 不阻塞地图与坐标点——详情页的主职责仍然是看轨迹。
  Future<void> _loadEvents() async {
    final trackId = widget.serverTrackId;
    if (trackId == null) return;
    if (!await AuthService.instance.isLoggedIn()) return;
    try {
      final rows = await ApiClient.instance.fetchTrackEvents(trackId);
      final events = rows
          .map(WorkEvent.fromJson)
          // 语义标注是给停留点打的；移动事件没有标签，不进这一屏
          .where((e) => e.isStay || (e.semanticLabel?.isNotEmpty ?? false))
          .toList();
      if (mounted) {
        setState(() {
          _events = events;
          _eventsLoaded = true;
        });
      }
    } catch (_) {
      // 静默降级：取不到语义标注时，地图与坐标点照常可用
    }
  }

  /// 用 dart:ui 画一个实心圆 PNG，作为 Marker 图标
  Future<Uint8List> _createCircleIcon(Color color) async {
    const size = 28.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = color,
    );
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('轨迹详情'),
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 地图区域
            SizedBox(
              height: 320,
              child: _mapReady ? _buildMap() : _buildMapPlaceholder(),
            ),
            const SizedBox(height: 16),
            // 轨迹信息卡片
            _buildTrackInfoCard(),
            if (_events.isNotEmpty || _eventsLoaded) ...[
              const SizedBox(height: 16),
              _buildEventsCard(),
            ],
            const SizedBox(height: 16),
            // 坐标点列表
            Expanded(
              child: _points.isEmpty
                  ? const Center(
                      child: Text(
                        '该轨迹暂无坐标点',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _points.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) =>
                          _buildPointItem(index, _points[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 高德地图：蓝色路径 + 起终点实心圆
  ///
  /// <p>key 未配置时给一句明确说明，不静默渲染空白地图——
  /// 空白地图看起来像"地图坏了"，而实际原因是构建时没带 --dart-define。</p>
  Widget _buildMap() {
    if (!ApiConfig.hasAmapKey) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '未配置高德地图 key。\n'
            '构建时请带 --dart-define=AMAP_KEY=你的key，详见 README。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return AMapWidget(
      apiKey: AMapApiKey(androidKey: ApiConfig.amapKey),
      privacyStatement: const AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
      initialCameraPosition: CameraPosition(target: _latLngs.first, zoom: 16),
      markers: _markers,
      polylines: _polylines,
    );
  }

  /// 地图占位（无坐标点时）
  Widget _buildMapPlaceholder() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Text(
        '暂无坐标点，无法展示地图',
        style: TextStyle(color: Colors.grey, fontSize: 15),
      ),
    );
  }

  /// 轨迹信息卡片
  Widget _buildTrackInfoCard() {
    final track = widget.track;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '名称：${track.name?.isNotEmpty == true ? track.name! : '未命名'}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '开始：${_formatTime(track.startTime)}',
            style: const TextStyle(color: Colors.black, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '结束：${track.endTime == null ? '-' : _formatTime(track.endTime!)}',
            style: const TextStyle(color: Colors.black, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '时长：${_formatDuration(track)} · 坐标点：${_points.length} 个',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// 语义标注卡片：这条轨迹的停留点与 AI 标签
  Widget _buildEventsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Color(0xFF73ACF6),
              ),
              const SizedBox(width: 6),
              const Text(
                'AI 语义标注',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_events.isEmpty)
            const Text(
              '该轨迹暂无语义标注结果（可能还在分析中）',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          else
            // 事件条数不多，但每条含理由，给个上限内部滚动，
            // 免得把下面的坐标点列表挤到看不见
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 168),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _events.length; i++) ...[
                      if (i > 0) const Divider(height: 20),
                      _buildEventRow(_events[i]),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 单条停留事件：语义标签 + 置信度，下面补时间、停留时长与地点
  Widget _buildEventRow(WorkEvent event) {
    final meta = <String>[
      if (event.startTime != null)
        '${_formatClock(event.startTime!)}'
            '${event.endTime == null ? '' : ' - ${_formatClock(event.endTime!)}'}',
      if (event.dwellText != null) '停留 ${event.dwellText}',
      if (event.poiName?.isNotEmpty == true) event.poiName!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.labelText,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (event.confidenceText != null)
              Text(
                '置信度 ${event.confidenceText}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            meta.join(' · '),
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          event.confirmText,
          style: TextStyle(
            fontSize: 12,
            color: switch (event.confirmStatus) {
              1 => const Color(0xFF2E7D32),
              2 => const Color(0xFFE53935),
              _ => Colors.grey,
            },
          ),
        ),
        if (event.aiReason?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            'AI 理由：${event.aiReason}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 单个坐标点条目
  Widget _buildPointItem(int index, TrackPoint point) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Color(0xFF73ACF6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
          ),
          Text(
            _formatClock(point.recordTime),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 格式化时间：yyyy-MM-dd HH:mm
  String _formatTime(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final mo = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final mi = time.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  /// 格式化时分秒：HH:mm:ss
  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// 格式化时长
  String _formatDuration(Track track) {
    if (!track.isFinished || track.endTime == null) return '进行中';
    final d = track.endTime!.difference(track.startTime);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
