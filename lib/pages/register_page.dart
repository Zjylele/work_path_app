import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// 注册页面：用户名 / 密码 / 昵称，注册成功后回登录页手动登录
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  bool _obscurePassword = true;

  /// 注册请求是否进行中
  bool _loading = false;

  static const double _fieldWidth = 300;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_loading) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final nickname = _nicknameController.text.trim();

    if (username.isEmpty || password.isEmpty || nickname.isEmpty) {
      _showSnack('请填写完整信息');
      return;
    }
    if (password.length < 6) {
      _showSnack('密码长度至少 6 位');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.register(username, password, nickname);
      if (!mounted) return;
      _showSnack('注册成功，请登录');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('注册失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message, textAlign: TextAlign.center)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景渐变（白 → 浅灰，与登录页一致）
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
                    const Text(
                      '注册账号',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: _fieldWidth,
                      child: _buildField(
                        controller: _usernameController,
                        hint: '用户名',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: _fieldWidth,
                      child: _buildField(
                        controller: _passwordController,
                        hint: '密码（至少 6 位）',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.black54,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: _fieldWidth,
                      child: _buildField(
                        controller: _nicknameController,
                        hint: '昵称',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: _fieldWidth,
                      child: FilledButton(
                        onPressed: _loading ? null : _handleRegister,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4B5969),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
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
                                '注册',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        '已有账号？去登录',
                        style: TextStyle(
                          color: Color(0xFF4B5969),
                          fontSize: 15,
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

  /// 白色圆角输入框
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
          prefixIcon: Icon(icon, color: Colors.black54),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
