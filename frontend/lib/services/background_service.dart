import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'sms_service.dart';

/// 后台轮询任务：App 关闭也能跑。
/// 1) 扫描快递短信 → 解析 → 自动建快递记录（仅 Android）
/// 2) 拉取后端未读通知 → 弹本地系统通知（解决“只在打开时才通知”的问题）
///
/// 国内手机大多没有 Google 服务、FCM 到不了，这里用 workmanager 定时轮询 + 本地通知兜底。

const String _taskName = 'express_bg_poll';
const String _uniqueName = 'express_bg_poll_periodic';

// 去重 / 进度的本地存储键
const String _kLastSmsScan = 'bg_lastSmsScanMillis';
const String _kRecordedCodes = 'bg_recordedCodes'; // 已自动记录过的取件码
const String _kShownNotifIds = 'bg_shownNotifIds'; // 已弹过的通知 id

const String _channelId = 'express_default';
const String _channelName = '快递通知';

final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();

Future<void> _initNotif() async {
  await _notif.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));
}

Future<void> _showLocal(int id, String? title, String? body) async {
  await _notif.show(
    id,
    title ?? '快递提醒',
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '快递取件相关通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

// 构造建快递请求体：后端 zod 校验不接受 null，必须省略空字段。
Map<String, dynamic> _parcelBody({
  String? company,
  required String pickupCode,
  String? locker,
  String? location,
}) {
  final body = <String, dynamic>{'pickupCode': pickupCode, 'source': 'sms'};
  if (company != null && company.isNotEmpty) body['company'] = company;
  if (locker != null && locker.isNotEmpty) body['locker'] = locker;
  if (location != null && location.isNotEmpty) body['location'] = location;
  return body;
}

/// 扫快递短信 → 解析 → 自动建档（去重）。返回本次新增条数。
Future<int> _scanSmsAndRecord(SharedPreferences prefs) async {
  if (!Platform.isAndroid) return 0;
  final api = ApiService();
  final since = prefs.getInt(_kLastSmsScan) ??
      (DateTime.now().millisecondsSinceEpoch - 24 * 3600 * 1000); // 首次只看近 24h
  final recorded = (prefs.getStringList(_kRecordedCodes) ?? <String>[]).toSet();

  final msgs = await SmsService.fetchExpressSms(since: since);
  int maxDate = since;
  int added = 0;

  for (final m in msgs) {
    if ((m.date ?? 0) > maxDate) maxDate = m.date!;
    final text = m.body ?? '';
    if (text.isEmpty) continue;
    try {
      final parsed = await api.parse(text);
      final code = parsed.pickupCode;
      if (code == null || code.isEmpty) continue; // 没识别到取件码，跳过
      if (recorded.contains(code)) continue; // 已记录过，去重
      await api.addParcel(_parcelBody(
        company: parsed.company,
        pickupCode: code,
        locker: parsed.locker,
        location: parsed.location,
      ));
      recorded.add(code);
      added++;
      // 不在这里弹“已记录”通知：建档时后端会产生 new_parcel 通知，
      // 由下面的 _pollNotifications 统一弹出，避免重复。
    } catch (_) {/* 单条失败不影响其它 */}
  }

  // 截断去重集合，避免无限增长
  final trimmed = recorded.toList();
  if (trimmed.length > 200) trimmed.removeRange(0, trimmed.length - 200);
  await prefs.setStringList(_kRecordedCodes, trimmed);
  await prefs.setInt(_kLastSmsScan, maxDate);
  return added;
}

/// 拉取后端未读通知 → 弹本地通知。
/// 关键去重：弹完立刻在服务端标记已读，后端下一轮不再返回，
/// 彻底杜绝「同一条反复弹/刷屏」（不依赖本地缓存，跨 isolate 也安全）。
/// 同时每轮最多弹 _kMaxPerPoll 条，避免积压时一次性炸屏。
const int _kMaxPerPoll = 5;

Future<void> _pollNotifications(SharedPreferences prefs) async {
  final api = ApiService();
  final shown = (prefs.getStringList(_kShownNotifIds) ?? <String>[]).toSet();
  final data = await api.notifications();
  final list = (data['notifications'] as List?) ?? const [];

  int budget = _kMaxPerPoll;
  for (final n in list) {
    final id = n['id']?.toString();
    if (id == null) continue;
    if (n['read'] == true) continue; // 已读不弹
    if (shown.contains(id)) continue; // 本地也兜底去重
    // 超出本轮上限的，仅静默标记已读（视为积压/清账），不再弹出
    if (budget > 0) {
      await _showLocal(id.hashCode, n['title']?.toString(), n['body']?.toString());
      budget--;
    }
    shown.add(id);
    try {
      await api.markRead(id: id); // 服务端标记已读 → 下轮不再返回，根治刷屏
    } catch (_) {/* 标记失败本地集合也已兜底 */}
  }

  final trimmed = shown.toList();
  if (trimmed.length > 300) trimmed.removeRange(0, trimmed.length - 300);
  await prefs.setStringList(_kShownNotifIds, trimmed);
}

/// workmanager 后台入口（独立 isolate，必须是顶层函数 + vm:entry-point）。
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await _initNotif();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('token') == null) return true; // 未登录，跳过
      await _scanSmsAndRecord(prefs);
      await _pollNotifications(prefs);
    } catch (_) {/* 后台异常静默，等下个周期重试 */}
    return true;
  });
}

class BackgroundService {
  /// App 启动时调用一次（注册后台入口）。
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// 登录后调用：注册周期任务（WorkManager 最短周期 15 分钟）。
  static Future<void> registerPeriodic() async {
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(minutes: 15),
      // workmanager 0.9：周期任务的策略类型改为 ExistingPeriodicWorkPolicy
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// 仅取消 workmanager 周期任务，保留去重状态。
  /// 现在通知统一由前台常驻服务轮询，workmanager 不再参与，避免两个轮询器重复弹。
  static Future<void> disablePeriodic() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
  }

  /// 退出登录时调用：取消后台任务并清理去重状态。
  static Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSmsScan);
    await prefs.remove(_kRecordedCodes);
    await prefs.remove(_kShownNotifIds);
  }

  /// 前台手动触发一次（设置页“立即扫描”按钮）。返回本次新增的快递条数。
  static Future<int> runOnceNow() async {
    await _initNotif();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('token') == null) return 0;
    final added = await _scanSmsAndRecord(prefs);
    await _pollNotifications(prefs);
    return added;
  }
}

// ==================== 前台常驻服务（国产手机保活）====================
// workmanager 在国产 ROM 上「划掉 App」后会被杀；前台服务靠通知栏一条常驻通知
// 把进程保活，关 App 也能继续轮询收通知。
// 现在它是【唯一】的轮询器（workmanager 已停用），不存在两个轮询器重复弹的问题。

/// 前台服务任务入口（独立 isolate，必须是顶层函数 + vm:entry-point）。
@pragma('vm:entry-point')
void foregroundCallback() {
  FlutterForegroundTask.setTaskHandler(_ExpressTaskHandler());
}

class _ExpressTaskHandler extends TaskHandler {
  bool _busy = false; // 重入锁：上一轮没跑完就跳过，避免重叠执行重复弹

  // 一轮：扫短信自动记录 + 拉后端未读通知并弹本地通知
  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      // 后台 isolate 需手动注册插件，否则 SharedPreferences / 通知插件不可用
      WidgetsFlutterBinding.ensureInitialized();
      await _initNotif();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('token') == null) return; // 未登录跳过
      await _scanSmsAndRecord(prefs);
      await _pollNotifications(prefs);
    } catch (_) {/* 单轮异常静默，下一轮重试 */}
    finally {
      _busy = false;
    }
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async => _poll();

  @override
  void onRepeatEvent(DateTime timestamp) => _poll();

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// 前台常驻服务的启停封装。
class ForegroundService {
  static void _initOptions() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'express_fg',
        channelName: '快递助手保活',
        channelDescription: '让 App 关闭后也能继续接收快递通知',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5 * 60 * 1000), // 每 5 分钟一轮
        autoRunOnBoot: true, // 开机自启
        autoRunOnMyPackageReplaced: true, // 更新后自启
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// 登录后调用：启动前台常驻服务（仅 Android）。
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    _initOptions();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '快递助手运行中',
      notificationText: '正在为你留意新快递与取件提醒',
      callback: foregroundCallback,
    );
  }

  /// 退出登录调用：停止前台服务。
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
