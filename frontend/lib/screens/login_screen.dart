import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/errors.dart';

/// 登录 / 注册页
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isRegister = false;
  final account = TextEditingController();
  final password = TextEditingController();
  final nickname = TextEditingController();
  bool loading = false;

  void _hint(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
      );

  Future<void> _submit() async {
    // 客户端即时校验，给出比服务器更直白的提示
    final acc = account.text.trim();
    if (acc.isEmpty) return _hint('请输入手机号或邮箱');
    if (password.text.length < 6) return _hint('密码至少 6 位');

    setState(() => loading = true);
    final auth = context.read<AuthProvider>();
    try {
      if (isRegister) {
        final isEmail = acc.contains('@');
        await auth.register({
          if (isEmail) 'email': acc else 'phone': acc,
          'password': password.text,
          if (nickname.text.isNotEmpty) 'nickname': nickname.text,
        });
      } else {
        await auth.login(acc, password.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade600),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.local_shipping, size: 64, color: Color(0xFF3A7AFE)),
                const SizedBox(height: 12),
                Text(isRegister ? '注册账号' : '登录',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextField(
                  controller: account,
                  decoration: const InputDecoration(labelText: '手机号 / 邮箱', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (isRegister) ...[
                  TextField(
                    controller: nickname,
                    decoration: const InputDecoration(labelText: '昵称（可选）', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(isRegister ? '注册' : '登录'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => isRegister = !isRegister),
                  child: Text(isRegister ? '已有账号？去登录' : '没有账号？去注册'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
