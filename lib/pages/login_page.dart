import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'register_page.dart';

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

  /// 登录请求是否进行中（防止重复提交）
  bool _loading = false;

  /// 输入框与登录按钮的固定宽度（不占满屏幕宽度）
  static const double _fieldWidth = 300;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 登录按钮点击逻辑：调后端校验，成功跳首页，失败弹提示
  Future<void> _handleLogin() async {
    if (_loading) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showLoginFailedDialog('请输入用户名和密码');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.login(username, password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => HomePage(username: username)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showLoginFailedDialog(e.message);
    } catch (_) {
      if (!mounted) return;
      _showLoginFailedDialog('登录失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 显示登录失败提示，2 秒后自动消失
  void _showLoginFailedDialog(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图层：白→浅灰渐变；后续插入背景图时替换此处即可
          widget.background ??
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFFFFF), Color(0xFFF7F8FA)],
                  ),
                ),
              ),
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
                    // 注册入口：跳转注册页，注册成功后回登录页手动登录
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<bool>(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: _LinkText('注册账号'),
                        ),
                      ),
                    ),
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
      children: [_LinkText('短信验证码登录'), _LinkText('忘记密码')],
    );
  }

  /// 登录按钮：蓝色背景、圆角矩形、白色居中文字；加载中显示转圈并禁用
  Widget _buildLoginButton() {
    return FilledButton(
      onPressed: _loading ? null : _handleLogin,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF4B5969),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
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
      style: const TextStyle(color: Color(0xFF4B5969), fontSize: 15),
    );
  }
}
