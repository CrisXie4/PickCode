import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// 真实推送：FCM（Android/iOS 通用）。
/// 登录成功后调用 PushService.instance.setup()。
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _api = ApiService();

  Future<void> init() async {
    await Firebase.initializeApp();
    // 本地通知（用于 App 在前台时弹出）
    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
  }

  /// 登录后调用：申请权限 + 拿 token + 上报后端 + 监听消息
  Future<void> setup() async {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(alert: true, badge: true, sound: true);

    final token = await fm.getToken();
    if (token != null) {
      await _api.registerDeviceToken(token, Platform.isIOS ? 'ios' : 'android');
    }
    // token 刷新时重新上报
    fm.onTokenRefresh.listen((t) {
      _api.registerDeviceToken(t, Platform.isIOS ? 'ios' : 'android');
    });

    // 前台收到消息 → 用本地通知弹出
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        _local.show(
          n.hashCode,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails('default', '默认通知', importance: Importance.high),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    });
  }
}
