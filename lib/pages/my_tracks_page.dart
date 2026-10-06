import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/track_database.dart';
import '../services/track_upload_service.dart';
import 'track_detail_page.dart';

/// 我的轨迹详情页：展示当前用户所有轨迹
class MyTracksPage extends StatefulWidget {
  const MyTracksPage({super.key, this.username});

  /// 当前登录用户名/手机号
  final String? username;

  @override
  State<MyTracksPage> createState() => _MyTracksPageState();
}

class _MyTracksPageState extends State<MyTracksPage> {
  List<Track> _tracks = [];

  /// trackId -> 坐标点数
  final Map<String, int> _pointCounts = {};

  /// 本地轨迹 UUID -> 服务端分析状态（0/1/2/3）
  ///
  /// 分析状态只存在于服务端，本地 sqflite 存不了；两边靠 clientTrackId 对上
  /// ——它正是上传时的幂等键。
  Map<String, int> _analysisStatus = {};

  /// 是否正在补传
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final tracks = await TrackDatabase.instance
        .getTracks(userId: widget.username);
    final counts = <String, int>{};
    for (final track in tracks) {
      counts[track.id] =
          (await TrackDatabase.instance.getTrackPoints(track.id)).length;
    }
    if (mounted) {
      setState(() {
        _tracks = tracks;
        _pointCounts
          ..clear()
          ..addAll(counts);
      });
    }
    await _loadAnalysisStatus();
  }

  /// 拉服务端轨迹列表，按 clientTrackId 建立「本地轨迹 → 分析状态」映射。
  ///
  /// 拉不到就保持空映射（列表照常显示，只是没有分析状态）——
  /// 这是一个增强信息，不该因为它让整页报错，也不该阻塞本地轨迹与补传。
  Future<void> _loadAnalysisStatus() async {
    if (!await AuthService.instance.isLoggedIn()) return;
    try {
      final data = await ApiClient.instance.fetchMyTracks();
      final list = (data['list'] as List?) ?? const [];
      final map = <String, int>{};
      for (final item in list) {
        if (item is! Map) continue;
        final cid = item['clientTrackId'] as String?;
        final status = item['analysisStatus'] as num?;
        if (cid != null && cid.isNotEmpty && status != null) {
          map[cid] = status.toInt();
        }
      }
      if (mounted) setState(() => _analysisStatus = map);
    } catch (_) {
      // 静默降级
    }
  }

  /// 补传所有待上传/失败的轨迹
  Future<void> _retryAll() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    final result = await TrackUploadService.instance.uploadPending();
    if (!mounted) return;
    setState(() => _uploading = false);
    _loadTracks();
    _showSnack(
      result.failed == 0
          ? '补传完成：${result.success} 条'
          : '补传完成：成功 ${result.success} 条，失败 ${result.failed} 条',
    );
  }

  /// 重传单条失败的轨迹
  Future<void> _retrySingle(Track track) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      await TrackUploadService.instance.uploadTrack(track);
      if (!mounted) return;
      _showSnack('轨迹已上传');
    } catch (_) {
      if (!mounted) return;
      _showSnack('上传失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _uploading = false);
      _loadTracks();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('我的轨迹'),
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: '补传未上传轨迹',
            onPressed: _uploading ? null : _retryAll,
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _tracks.isEmpty
            ? const Center(
                child: Text(
                  '暂无轨迹',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                itemCount: _tracks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) =>
                    _buildTrackItem(context, _tracks[index]),
              ),
      ),
    );
  }

  /// 单条轨迹卡片
  Widget _buildTrackItem(BuildContext context, Track track) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailPage(track: track),
          ),
        );
      },
      child: Container(
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
                Expanded(
                  child: Text(
                    // 名称是轨迹的主标识；v3 前记录的旧轨迹没有名称
                    track.name?.isNotEmpty == true ? track.name! : '未命名轨迹',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildUploadBadge(track),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '开始于 ${_formatTime(track.startTime)} · 时长 ${_formatDuration(track)} · ${_pointCounts[track.id] ?? 0} 个坐标点',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            if (_analysisStatus[track.id] != null) ...[
              const SizedBox(height: 6),
              _buildAnalysisBadge(_analysisStatus[track.id]!),
            ],
            if (track.uploadStatus == 2) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _uploading ? null : () => _retrySingle(track),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重新上传'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 分析状态角标：未分析(灰) / 分析中(蓝) / 已分析(绿) / 分析失败(红)
  ///
  /// 与上传状态是两个维度：上传成功不等于分析完成，分开显示才能让
  /// 「传给谁了」和「AI 看没看」各自可辨。
  Widget _buildAnalysisBadge(int status) {
    final (text, color) = switch (status) {
      0 => ('未分析', Colors.grey),
      1 => ('分析中', const Color(0xFF1565C0)),
      2 => ('已分析', const Color(0xFF2E7D32)),
      3 => ('分析失败', const Color(0xFFE53935)),
      _ => ('未知', Colors.grey),
    };
    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 14, color: color),
        const SizedBox(width: 4),
        Text('AI $text', style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  /// 上传状态角标：已上传(绿) / 上传失败(红) / 待上传(灰)
  Widget _buildUploadBadge(Track track) {
    final (text, color) = switch (track.uploadStatus) {
      1 => ('已上传', const Color(0xFF2E7D32)),
      2 => ('上传失败', const Color(0xFFE53935)),
      _ => ('待上传', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
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
