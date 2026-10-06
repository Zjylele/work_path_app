import 'package:flutter/material.dart';

import '../models/rectification_order.dart';
import '../services/api_client.dart';

/// 我的整改工单页
///
/// 员工侧只有两个动作：提交处理说明与申诉。工单由管理员下发、也由管理员
/// 闭环——这一页刻意不提供「关闭」按钮，因为员工无法自行闭环是状态机的
/// 硬约束，不是界面取舍。
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<RectificationOrder> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ApiClient.instance.fetchMyOrders();
      final orders = rows.map(RectificationOrder.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// 提交处理说明（0 待处理 → 1 处理中）
  Future<void> _handle(RectificationOrder order) async {
    final note = await _promptText(
      title: '提交处理说明',
      hint: '说明你的整改情况（不超过 500 字）',
      confirmText: '提交',
    );
    if (note == null) return;
    try {
      await ApiClient.instance.handleOrder(order.orderId, note);
      _snack('已提交处理说明，等待管理员确认');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  /// 提交申诉（0 待处理 → 3 申诉中）
  Future<void> _appeal(RectificationOrder order) async {
    final reason = await _promptText(
      title: '提交申诉',
      hint: '说明申诉理由（不超过 500 字）',
      confirmText: '提交申诉',
    );
    if (reason == null) return;
    try {
      await ApiClient.instance.appealOrder(order.orderId, reason);
      _snack('已提交申诉，等待管理员复核');
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  /// 通用文本输入弹窗；取消返回 null，输入为空不提交
  Future<String?> _promptText({
    required String title,
    required String hint,
    required String confirmText,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(ctx).pop(text);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _snack(String message) {
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
        title: const Text('我的工单'),
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Text(
          '暂无整改工单',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _buildOrderCard(_orders[index]),
    );
  }

  Widget _buildOrderCard(RectificationOrder order) {
    final color = _statusColor(order.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '工单 #${order.orderId}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.statusText,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            order.content,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          if (order.handleNote != null) ...[
            const SizedBox(height: 8),
            _kv('我的说明', order.handleNote!),
          ],
          if (order.appealReason != null) ...[
            const SizedBox(height: 8),
            _kv('申诉理由', order.appealReason!),
          ],
          if (order.reviewNote != null) ...[
            const SizedBox(height: 8),
            _kv('管理员复核', order.reviewNote!),
          ],
          if (order.canAct) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handle(order),
                    child: const Text('提交处理说明'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _appeal(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                    ),
                    child: const Text('申诉'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
        children: [
          TextSpan(
            text: '$label：',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Color _statusColor(int status) => switch (status) {
        0 => const Color(0xFFE65100),
        1 => const Color(0xFF1565C0),
        2 => const Color(0xFF2E7D32),
        3 => const Color(0xFFE53935),
        _ => Colors.grey,
      };
}
