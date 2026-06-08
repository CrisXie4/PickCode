import 'package:dio/dio.dart';

/// 把各种异常转成普通用户看得懂的中文提示。
///
/// 原则：
/// 1. 优先用后端返回的 message（如「密码错误」「账号不存在」「该用户不是群成员」）；
/// 2. 网络类问题给「网络」相关的话；
/// 3. 其余一律给通用兜底，**绝不把原始英文堆栈/DioException 丢给用户**。
String friendlyError(Object? error) {
  if (error is DioException) {
    // 后端统一用 { message: '...' } 返回错误，直接取出来给用户看
    final data = error.response?.data;
    if (data is Map && data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
      return (data['message'] as String).trim();
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络有点慢，请稍后重试';
      case DioExceptionType.connectionError:
        return '连不上服务器，请检查网络后重试';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        if (code == 401) return '账号或密码错误';
        if (code == 403) return '没有操作权限';
        if (code == 404) return '内容不存在或已被删除';
        if (code != null && code >= 500) return '服务器繁忙，请稍后再试';
        return '操作失败，请稍后重试';
      default:
        return '网络异常，请稍后重试';
    }
  }
  return '操作失败，请稍后重试';
}
