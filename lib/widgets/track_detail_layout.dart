import 'package:flutter/material.dart';

/// 地图保留独立手势区域，详情共用滚动控制器，避免固定高度挤压内容。
class TrackDetailLayout extends StatelessWidget {
  const TrackDetailLayout({
    super.key,
    required this.map,
    required this.summary,
    required this.pointCount,
    required this.pointBuilder,
    this.events,
  });

  final Widget map;
  final Widget summary;
  final Widget? events;
  final int pointCount;
  final IndexedWidgetBuilder pointBuilder;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: map),
      DraggableScrollableSheet(
        initialChildSize: 0.44,
        minChildSize: 0.18,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.18, 0.44, 0.9],
        builder: (context, controller) => Material(
          color: const Color(0xFFF7F8FA),
          elevation: 5,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD1D7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '上拉查看详情 · 下拉展开地图',
                        style: TextStyle(
                          color: Color(0xFF717780),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: summary),
              if (events != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: events!,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Text(
                    '坐标点 · $pointCount',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (pointCount == 0)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '该轨迹暂无坐标点',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: pointBuilder(context, index),
                      ),
                      childCount: pointCount,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
