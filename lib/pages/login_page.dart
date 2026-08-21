import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_page.dart';

/// 登录页面
///
/// 背景层预留了 [background] 参数作为插入背景图的"口径"：
/// 之后只需在创建时传入背景图组件即可覆盖当前占位背景，例如：
/// `LoginPage(background: Image.asset('assets/images/bg.png', fit: BoxFit.cover))`
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.background});

  /// 背景图层，默认使用粉色占位背景便于预览页面效果
  final Widget? background;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// 密码是否以密文形式显示
  bool _obscurePassword = true;

  /// 输入框与登录按钮的固定宽度（不占满屏幕宽度）
  static const double _fieldWidth = 300;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 登录按钮点击逻辑：校验登录信息，正确则跳转首页，错误则弹出提示
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // 阶段一：本地内置账号校验（admin/123456）
    // TODO: 阶段二接入真实登录接口后，替换为请求后端校验
    final ok = await AuthService.instance.login(username, password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => HomePage(username: username)),
      );
    } else {
      _showLoginFailedDialog();
    }
  }

  /// 显示"登录失败，用户名或密码错误"底部提示，2 秒后自动消失
  void _showLoginFailedDialog() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            '登录失败，用户名或密码错误',
            textAlign: TextAlign.center,
          ),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图层：目前为粉色占位，后续插入背景图时替换此处即可
          widget.background ?? const ColoredBox(color: Color(0xFF898989)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 页面标题
                    const Text(
                      '登录页面',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(width: _fieldWidth, child: _buildUsernameField()),
                    const SizedBox(height: 16),
                    SizedBox(width: _fieldWidth, child: _buildPasswordField()),
                    const SizedBox(height: 12),
                    SizedBox(width: _fieldWidth, child: _buildLinksRow()),
                    const SizedBox(height: 32),
                    SizedBox(width: _fieldWidth, child: _buildLoginButton()),
                    const SizedBox(height: 16),
                    const Center(child: _LinkText('注册账号')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 用户名/手机号输入框：白色背景、圆角矩形、黑色文字
  Widget _buildUsernameField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: _usernameController,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: const InputDecoration(
          hintText: '用户名/手机号',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
          prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  /// 密码输入框：白色背景、圆角矩形、黑色文字，支持隐藏/显示密码
  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          hintText: '密码',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.black54,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  /// 短信验证码登录 / 忘记密码 文本链接
  Widget _buildLinksRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _LinkText('短信验证码登录'),
        _LinkText('忘记密码'),
      ],
    );
  }

  /// 登录按钮：蓝色背景、圆角矩形、白色居中文字
  Widget _buildLoginButton() {
    return FilledButton(
      onPressed: _handleLogin,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF73ACF6),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: const Text(
        '登录',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}

/// 文本形式的链接（暂无功能，仅展示样式）
class _LinkText extends StatelessWidget {
  const _LinkText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF73ACF6), fontSize: 15),
    );
  }
}
