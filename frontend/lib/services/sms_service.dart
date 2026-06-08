import 'dart:io';
import 'package:another_telephony/telephony.dart';

/// 短信读取与「快递相关」筛选（仅 Android）。
/// iOS 系统禁止第三方 App 读取短信，这里直接返回空。
class SmsService {
  static final Telephony _telephony = Telephony.instance;

  /// 快递短信关键词：命中任一即认为是快递相关短信。
  static const List<String> keywords = [
    '取件码', '取件', '取货码', '提货码', '凭码', '自提',
    '驿站', '丰巢', '菜鸟', '速递易', '兔喜', '妈妈驿站', '快递柜', '代收',
    '快递', '快件', '包裹', '取件通知',
  ];

  static bool isExpress(String body) => keywords.any((k) => body.contains(k));

  /// 申请短信读取权限（会弹系统授权框）。返回是否已授权。
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    final granted = await _telephony.requestSmsPermissions;
    return granted ?? false;
  }

  /// 读取「收件箱中、晚于 since(毫秒) 的快递相关短信」。
  /// 在 Dart 侧再过滤一遍关键词，避免误抓验证码等无关短信。
  static Future<List<SmsMessage>> fetchExpressSms({required int since}) async {
    if (!Platform.isAndroid) return [];
    final msgs = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(SmsColumn.DATE).greaterThan(since.toString()),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    return msgs
        .where((m) => (m.date ?? 0) > since && (m.body ?? '').isNotEmpty && isExpress(m.body!))
        .toList();
  }
}
