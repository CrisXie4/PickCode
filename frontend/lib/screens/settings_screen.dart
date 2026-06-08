import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/sms_service.dart';
import '../services/background_service.dart';
import '../services/update_service.dart';
import '../utils/text.dart';
import '../utils/errors.dart';

/// 个人设置页：昵称/头像、退出登录、用户 ID
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: (user?.avatarUrl != null) ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null ? Text(initial(user?.nickname), style: const TextStyle(fontSize: 28)) : null,
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(user?.nickname ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Center(child: Text('ID: ${user?.id ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('修改昵称'),
            onTap: () => _editNickname(context, auth),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('修改头像（填图片 URL）'),
            onTap: () => _editAvatar(context, auth),
          ),
          if (user?.isAdmin == true)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('打开 Web 管理后台'),
              subtitle: const Text('用浏览器打开，用本账号登录'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openAdmin(context),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('立即扫描短信'),
            subtitle: const Text('从短信中识别并自动记录快递（仅 Android，每 15 分钟也会自动后台扫描）'),
            onTap: () => _scanSmsNow(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('从 GitHub 检查是否有新版本'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => UpdateService.promptIfAvailable(context, silent: false),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () => auth.logout(),
          ),
        ],
      ),
    );
  }

  // 在外部浏览器打开 Web 管理后台
  Future<void> _openAdmin(BuildContext context) async {
    final uri = Uri.parse(ApiClient.adminUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开浏览器，请手动访问：${ApiClient.adminUrl}')),
      );
    }
  }

  // 申请短信权限并立即扫描一次（前台手动触发）
  Future<void> _scanSmsNow(BuildContext context) async {
    final granted = await SmsService.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未获得短信权限（iOS 不支持读取短信）')),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在扫描短信…')));
    }
    try {
      final added = await BackgroundService.runOnceNow();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(added > 0 ? '已自动记录 $added 条快递' : '没有发现新的快递短信')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _editNickname(BuildContext context, AuthProvider auth) async {
    final ctrl = TextEditingController(text: auth.user?.nickname);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await auth.updateProfile({'nickname': ctrl.text.trim()});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称已更新')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
  }

  Future<void> _editAvatar(BuildContext context, AuthProvider auth) async {
    final ctrl = TextEditingController(text: auth.user?.avatarUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('修改头像 URL'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'https://...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await auth.updateProfile({'avatarUrl': ctrl.text.trim()});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
  }
}
