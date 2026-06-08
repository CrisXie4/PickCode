import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import '../services/background_service.dart';
import '../services/sms_service.dart';
import '../models/models.dart';

/// 全局登录态
class AuthProvider extends ChangeNotifier {
  final _api = ApiService();
  AppUser? user;
  bool loading = true;

  bool get isLoggedIn => user != null;

  /// 启动时尝试用本地 token 恢复登录
  Future<void> bootstrap() async {
    final token = await ApiClient.instance.getToken();
    if (token != null) {
      try {
        user = await _api.me();
      } catch (_) {
        await ApiClient.instance.clearToken();
      }
    }
    if (user != null) {
      _trySetupPush();
      _trySetupBackground();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String account, String password) async {
    final res = await _api.login(account, password);
    await ApiClient.instance.saveToken(res['token']);
    user = AppUser.fromJson(res['user']);
    _trySetupPush();
    _trySetupBackground();
    notifyListeners();
  }

  Future<void> register(Map<String, dynamic> body) async {
    final res = await _api.register(body);
    await ApiClient.instance.saveToken(res['token']);
    user = AppUser.fromJson(res['user']);
    _trySetupPush();
    _trySetupBackground();
    notifyListeners();
  }

  // 配置了 Firebase 才生效；未配置时安全跳过，不影响 App 运行
  Future<void> _trySetupPush() async {
    try {
      await PushService.instance.setup();
    } catch (_) {/* Firebase 未配置，忽略 */}
  }

  // 申请短信/通知权限并启动后台机制（前台常驻服务 + workmanager 轮询）。失败不影响登录。
  Future<void> _trySetupBackground() async {
    try {
      await Permission.notification.request(); // Android 13+ 需运行时授权
      await SmsService.requestPermission(); // 仅 Android 弹框；iOS 直接返回 false
      // 申请「忽略电池优化」，提升前台服务存活率（国产 ROM 关键）
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      await ForegroundService.start(); // 前台常驻服务：关 App 也能收通知（唯一轮询器）
      await BackgroundService.disablePeriodic(); // 停掉 workmanager，避免两个轮询器重复弹/刷屏
    } catch (_) {/* 权限被拒或平台不支持，忽略 */}
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    user = await _api.updateProfile(body);
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.instance.clearToken();
    await ForegroundService.stop(); // 停掉前台常驻服务
    await BackgroundService.cancel(); // 停掉后台轮询并清理去重状态
    user = null;
    notifyListeners();
  }
}
