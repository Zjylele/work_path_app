import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// 个人信息页：展示当前登录用户信息，支持修改昵称
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.username});

  /// 当前登录用户名/手机号
  final String? username;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// 当前昵称（null 表示未加载成功）
  String? _nickname;

  /// 是否正在加载/保存
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// 从后端拉取当前用户信息（含昵称）
  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.instance.info();
      if (mounted) {
        setState(() {
          _nickname = data['nickname'] as String?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 修改昵称：弹输入框 → 调后端保存 → 刷新
  Future<void> _editNickname() async {
    final controller = TextEditingController(text: _nickname ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(hintText: '请输入新昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;

    setState(() => _loading = true);
    try {
      final data = await ApiClient.instance.updateProfile(value);
      if (mounted) {
        setState(() {
          _nickname = (data['nickname'] as String?) ?? value;
          _loading = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('昵称已更新')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _nickname ?? widget.username ?? '未登录';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('个人信息'),
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // 头像
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF73ACF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              // 昵称 + 用户名
              Text(
                _loading ? '加载中…' : displayName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '账号：${widget.username ?? '-'}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              // 昵称编辑入口
              _buildInfoCard(context, '昵称', displayName, onEdit: _editNickname),
              const SizedBox(height: 12),
              _buildInfoCard(context, '账号', widget.username ?? '-'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black, fontSize: 15),
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: const Text(
                '修改',
                style: TextStyle(color: Color(0xFF73ACF6), fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}
