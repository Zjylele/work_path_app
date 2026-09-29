import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/track_database.dart';
import 'my_page.dart';
import 'my_tracks_page.dart';
import 'record_track_page.dart';

/// 首页
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.username});

  /// 登录成功的用户名/手机号
  final String? username;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 最近轨迹（至多 3 条）
  List<Track> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  /// 从数据库加载当前用户最近轨迹
  Future<void> _loadTracks() async {
    final tracks = await TrackDatabase.instance
        .getTracks(userId: widget.username, limit: 3);
    if (mounted) setState(() => _tracks = tracks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // 可滚动内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 顶部问候语
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '你好，${widget.username ?? ''}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStartRecordButton(),
                    const SizedBox(height: 32),
                    _buildMyTracksCard(context),
                  ],
                ),
              ),
            ),
            // 底部导航栏
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  /// 顶部按钮：开始记录工作轨迹
  Widget _buildStartRecordButton() {
    return GestureDetector(
      onTap: () async {
        // 进入记录页；返回后刷新轨迹列表
        await Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => RecordTrackPage(username: widget.username ?? ''),
          ),
        );
        _loadTracks();
      },
      child: Container(
        width: 300,
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF73ACF6),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3373ACF6),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          '开始记录工作轨迹',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 中间区域：我的轨迹（可点击，跳转详情页）
  Widget _buildMyTracksCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyTracksPage(username: widget.username),
          ),
        );
      },
      child: Container(
        width: 300,
        height: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFBBD3F8), width: 1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '我的轨迹',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 轨迹列表区域可滚动，避免卡片过多时底部溢出
            Expanded(
              child: _buildTrackItems(),
            ),
          ],
        ),
      ),
    );
  }

  /// 生成轨迹列表；无数据时显示"暂无轨迹"
  Widget _buildTrackItems() {
    if (_tracks.isEmpty) {
      return const Center(
        child: Text(
          '暂无轨迹',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _buildTrackItem(_tracks[index]),
    );
  }

  /// 单条轨迹卡片
  Widget _buildTrackItem(Track track) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '开始于 ${_formatTime(track.startTime)}',
            style: const TextStyle(color: Colors.black, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDuration(track),
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

  /// 格式化时长：HH:mm:ss 或「进行中」
  String _formatDuration(Track track) {
    if (!track.isFinished || track.endTime == null) return '进行中';
    final d = track.endTime!.difference(track.startTime);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '时长 $h:$m:$s';
  }

  /// 底部导航栏：首页 / 我的
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                // 点击"首页"：保持在当前首页
              },
              child: const Center(
                child: Text(
                  '首页',
                  style: TextStyle(color: Colors.black, fontSize: 15),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MyPage(username: widget.username),
                  ),
                );
              },
              child: const Center(
                child: Text(
                  '我的',
                  style: TextStyle(color: Colors.black, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
