import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/errors.dart';

/// 一条可更新的版本信息。
class UpdateInfo {
  final String version; // 纯版本号，如 1.0.1
  final String tag; // 标签，如 v1.0.1
  final String notes; // 更新说明（Release body）
  final String? apkUrl; // .apk 资源的下载直链（可能为空）
  final String pageUrl; // Release 网页地址（兜底）

  UpdateInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.apkUrl,
    required this.pageUrl,
  });

  /// 优先用 apk 直链，没有就用 Release 页
  String get downloadUrl => (apkUrl != null && apkUrl!.isNotEmpty) ? apkUrl! : pageUrl;
}

/// 检查 GitHub Releases 是否有新版本，并提示用户更新。
class UpdateService {
  // 检查更新的 GitHub 仓库：构建时用 --dart-define=UPDATE_REPO=owner/repo 注入。
  // 默认空 = 关闭自动更新。自部署者指向自己的仓库，这样你推送的版本不会覆盖他们的用户。
  static const String repo = String.fromEnvironment('UPDATE_REPO', defaultValue: '');

  static bool get enabled => repo.isNotEmpty;

  /// 查询 GitHub 最新 Release；有新版返回 UpdateInfo，否则 null（未配置仓库时直接返回 null）。
  static Future<UpdateInfo?> check() async {
    if (!enabled) return null; // 未配置更新仓库 → 不检查
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final res = await dio.get(
      'https://api.github.com/repos/$repo/releases/latest',
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    final data = res.data as Map;
    final tag = (data['tag_name'] ?? '').toString();
    final current = (await PackageInfo.fromPlatform()).version;
    if (!_isNewer(_parse(tag), _parse(current))) return null;

    String? apkUrl;
    for (final a in (data['assets'] as List? ?? const [])) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = a['browser_download_url']?.toString();
        break;
      }
    }
    return UpdateInfo(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      tag: tag,
      notes: (data['body'] ?? '').toString().trim(),
      apkUrl: apkUrl,
      pageUrl: (data['html_url'] ?? 'https://github.com/$repo/releases').toString(),
    );
  }

  /// 检查并弹窗提示。silent=true 时（如启动自动检查）失败/已最新都不打扰用户。
  static Future<void> promptIfAvailable(BuildContext context, {bool silent = true}) async {
    UpdateInfo? info;
    try {
      info = await check();
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('检查更新失败：${friendlyError(e)}')));
      }
      return;
    }
    if (info == null) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已是最新版本 👍')));
      }
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('发现新版本 ${info!.tag}'),
        content: SingleChildScrollView(
          child: Text(info.notes.isEmpty ? '有新版本可用，建议更新。' : info.notes),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('稍后')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(info!.downloadUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('去更新'),
          ),
        ],
      ),
    );
  }

  // 从 "v1.2.3" / "1.2.3+4" 这类字符串里取出三段版本号
  static List<int> _parse(String v) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(v);
    if (m == null) return [0, 0, 0];
    return [int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)];
  }

  static bool _isNewer(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}
