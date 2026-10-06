import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'my_orders_page.dart';
import 'my_tracks_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';

/// 我的页面（个人信息/设置页）
class MyPage extends StatelessWidget {
  const MyPage({super.key, this.username});

  /// 当前登录用户的用户名/手机号
  final String? username;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  children: [
                    _buildUserInfo(),
                    const SizedBox(height: 24),
                    _buildMenuCard(context),
                    const SizedBox(height: 24),
                    _buildLogoutButton(context),
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

  /// 顶部用户信息区：头像 + 用户名/手机号
  /// 与下方菜单卡片同为 350 宽、水平居中，保证左边缘对齐
  Widget _buildUserInfo() {
    return SizedBox(
      width: 350,
      child: Row(
        children: [
          // 圆形头像，点击可上传/更换头像
          GestureDetector(
            onTap: () {
              // TODO: 上传头像
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              username == null || username!.isEmpty ? '未登录' : username!,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 中间菜单卡片
  Widget _buildMenuCard(BuildContext context) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildMenuItem('个人信息', onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfilePage(username: username),
              ),
            );
          }),
          _buildDivider(),
          _buildMenuItem('全部轨迹', onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MyTracksPage(username: username),
              ),
            );
          }),
          _buildDivider(),
          _buildMenuItem('我的工单', onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MyOrdersPage()),
            );
          }),
          _buildDivider(),
          _buildMenuItem('设置', onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            );
          }),
        ],
      ),
    );
  }

  /// 单条菜单项（可点击）
  Widget _buildMenuItem(String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        width: 300,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
      ),
    );
  }

  /// 菜单项之间的细分割线
  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0));
  }

  /// 退出登录按钮
  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // 清除本地登录态
        await AuthService.instance.logout();
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        );
      },
      child: Container(
        width: 300,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          '退出登录',
          style: TextStyle(
            color: Color(0xFFE53935),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
                // 点击"首页"：跳回首页，避免页面栈堆积
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => HomePage(username: username),
                  ),
                );
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
                // 点击"我的"：保持在当前页
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
