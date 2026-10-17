import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/track_database.dart';
import 'my_orders_page.dart';
import 'my_page.dart';
import 'my_tracks_page.dart';
import 'record_track_page.dart';
import 'track_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.username});
  final String? username;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _ink = Color(0xFF28333E);
  static const _muted = Color(0xFF717780);
  static const _line = Color(0xFFE8EAED);
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    if (widget.username == null || widget.username!.isEmpty) {
      if (mounted) {
        setState(() {
          _tracks = [];
          _loading = false;
        });
      }
      return;
    }
    try {
      final tracks = await TrackDatabase.instance.getTracks(
        userId: widget.username,
      );
      if (mounted) {
        setState(() {
          _tracks = tracks;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '轨迹加载失败，请下拉重试';
        });
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _tracks.where((t) => DateUtils.isSameDay(t.startTime, now));
    final distance = today.fold<double>(0, (sum, t) => sum + (t.distance ?? 0));
    final duration = today.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + (t.endTime ?? now).difference(t.startTime),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTracks,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WORKPATH',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '你好，${widget.username?.isNotEmpty == true ? widget.username : '工作伙伴'}',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '让今天的每一步，都有记录。',
                      style: TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 26),
                    _surface(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '准备开始今天的工作？',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '出发，记录新轨迹',
                            style: TextStyle(
                              fontSize: 23,
                              color: _ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '记录工作路线 · 自动保存轨迹',
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _open(
                                RecordTrackPage(
                                  username: widget.username ?? '',
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('开始记录工作轨迹'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 17,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final metrics = [
                          _metric(
                            '今日工作里程',
                            _loading || _error != null
                                ? '—'
                                : (distance / 1000).toStringAsFixed(1),
                            'km',
                          ),
                          _metric(
                            '今日工作时长',
                            _loading || _error != null
                                ? '—'
                                : (duration.inMinutes / 60).toStringAsFixed(1),
                            '小时',
                          ),
                        ];
                        if (constraints.maxWidth < 300) {
                          return Column(
                            children: [
                              metrics[0],
                              const SizedBox(height: 12),
                              metrics[1],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: metrics[0]),
                            const SizedBox(width: 12),
                            Expanded(child: metrics[1]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '最近轨迹',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _open(MyTracksPage(username: widget.username)),
                          child: const Text('查看全部 →'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _surface(
                      _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  '正在加载轨迹…',
                                  style: TextStyle(color: _muted),
                                ),
                              ),
                            )
                          : _error != null
                          ? Column(
                              children: [
                                Text(
                                  _error!,
                                  style: const TextStyle(color: _muted),
                                ),
                                TextButton(
                                  onPressed: _loadTracks,
                                  child: const Text('重新加载'),
                                ),
                              ],
                            )
                          : _tracks.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  '暂无轨迹，开始记录你的第一段工作路线',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _muted),
                                ),
                              ),
                            )
                          : Column(
                              children: _tracks
                                  .take(3)
                                  .map(_trackTile)
                                  .toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFEDF1F4),
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) _open(MyTracksPage(username: widget.username));
          if (index == 2) _open(const MyOrdersPage());
          if (index == 3) _open(MyPage(username: widget.username));
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(icon: Icon(Icons.route_outlined), label: '轨迹'),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: '工单',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }

  Widget _surface(Widget child) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: _line),
      borderRadius: BorderRadius.circular(20),
    ),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );

  Widget _metric(String label, String value, String unit) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 29,
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _trackTile(Track track) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _open(TrackDetailPage(track: track)),
      title: Text(
        track.name?.isNotEmpty == true ? track.name! : '未命名轨迹',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 15,
          color: _ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          '${_formatTime(track.startTime)}\n${_formatDuration(track)}',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ),
      trailing: Text(
        !track.isFinished
            ? '进行中'
            : track.uploadStatus == 1
            ? '已同步'
            : track.uploadStatus == 2
            ? '同步失败'
            : '待同步',
        style: TextStyle(
          fontSize: 12,
          color: track.uploadStatus == 2 ? const Color(0xFFB54736) : _muted,
        ),
      ),
    ),
  );

  String _formatTime(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDuration(Track track) {
    if (!track.isFinished || track.endTime == null) return '进行中';
    final d = track.endTime!.difference(track.startTime);
    return '时长 ${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
