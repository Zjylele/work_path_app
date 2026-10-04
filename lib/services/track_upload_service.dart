import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/track.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'track_database.dart';

/// 轨迹上传服务
///
/// - 结束轨迹后调用 [uploadTrack] 立即上传
/// - 失败自动标记「上传失败」，由 [uploadPending] 在启动/网络恢复/手动重试时补传
/// - 后端按 clientTrackId 幂等，重复上传不会产生重复数据
class TrackUploadService {
  TrackUploadService._();

  static final TrackUploadService instance = TrackUploadService._();

  /// 是否正在批量补传（防止并发触发）
  bool _uploading = false;

  /// 网络监听订阅（App 生命周期内只订阅一次）
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// 监听网络恢复：恢复联网后自动补传未上传轨迹（App 启动时调用一次）
  void watchConnectivity() {
    if (_connectivitySub != null) return;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final connected =
          results.any((result) => result != ConnectivityResult.none);
      if (connected) {
        _uploadOnConnectivity();
      }
    });
  }

  Future<void> _uploadOnConnectivity() async {
    // 未登录不补传（无 token，上传会 401）
    if (!await AuthService.instance.isLoggedIn()) return;
    await uploadPending();
  }

  /// 上传单条轨迹；成功标记已上传(1)，失败标记上传失败(2)并抛出异常
  Future<void> uploadTrack(Track track) async {
    final points = await TrackDatabase.instance.getTrackPoints(track.id);
    final payload = <String, dynamic>{
      'clientTrackId': track.id,
      // 名称随轨迹上传入库；旧轨迹（v3 前记录）为 null，后端按空名称接受
      'name': track.name,
      'startTime': _formatDateTime(track.startTime),
      'endTime': _formatDateTime(track.endTime ?? track.startTime),
      // 后端状态语义：1=进行中 2=已完成
      'status': track.isFinished ? 2 : 1,
      'distance': track.distance,
      'points': points
          .map(
            (p) => <String, dynamic>{
              'latitude': p.latitude,
              'longitude': p.longitude,
              'recordTime': _formatDateTime(p.recordTime),
            },
          )
          .toList(),
    };
    try {
      await ApiClient.instance.uploadTrack(payload);
      await TrackDatabase.instance.updateUploadStatus(track.id, 1);
    } catch (_) {
      await TrackDatabase.instance.updateUploadStatus(track.id, 2);
      rethrow;
    }
  }

  /// 补传所有待上传/上传失败的已完成轨迹，返回成功与失败条数
  Future<({int success, int failed})> uploadPending() async {
    // 并发保护：已在补传则直接返回，避免重复触发
    if (_uploading) return (success: 0, failed: 0);
    _uploading = true;
    try {
      final tracks = await TrackDatabase.instance.getUnuploadedTracks();
      var success = 0;
      var failed = 0;
      for (final track in tracks) {
        try {
          await uploadTrack(track);
          success++;
        } catch (_) {
          failed++;
        }
      }
      return (success: success, failed: failed);
    } finally {
      _uploading = false;
    }
  }

  /// 格式化时间为后端要求的 yyyy-MM-dd HH:mm:ss
  static String _formatDateTime(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final mo = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }
}
