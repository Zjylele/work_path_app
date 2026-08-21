import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/track_database.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('我的轨迹'),
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black,
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
            Text(
              '开始于 ${_formatTime(track.startTime)}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '时长 ${_formatDuration(track)} · ${_pointCounts[track.id] ?? 0} 个坐标点',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
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
