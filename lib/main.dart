import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 立即 runApp，避免启动阻塞导致黑屏；
  // 登录态在 _StartupGate 中异步加载，加载期间显示 loading 页。
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '工作轨迹',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF73ACF6)),
        scaffoldBackgroundColor: const Color(0xFFF8BBD0),
      ),
      home: const _StartupGate(),
    );
  }
}

/// 启动闸门：异步检查本地登录态，加载中显示 loading 页，避免黑屏
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _checked = false;
  bool _loggedIn = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    try {
      final loggedIn = await AuthService.instance.isLoggedIn();
      final username = await AuthService.instance.getUsername();
      if (mounted) {
        setState(() {
          _checked = true;
          _loggedIn = loggedIn;
          _username = username;
        });
      }
    } catch (_) {
      // 登录态读取失败时按未登录处理，保证 App 可进入
      if (mounted) {
        setState(() {
          _checked = true;
          _loggedIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      // 加载中：粉色背景 + loading，保证启动时有 UI
      return const Scaffold(
        backgroundColor: Color(0xFFF8BBD0),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF73ACF6)),
        ),
      );
    }
    return _loggedIn
        ? HomePage(username: _username)
        : const LoginPage();
  }
}
