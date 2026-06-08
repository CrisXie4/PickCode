import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统一的 API 客户端：注入 token、统一错误。
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // 服务器地址：构建时通过 --dart-define=API_BASE_URL=... 注入（见 env.example.json）。
  // 仓库里只留占位符，真实地址放在本地 env.json（已 gitignore），不会泄露。
  // 自部署者填自己的地址即可，不会连到他人的服务器。
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://your-server.example.com/api',
  );

  // Web 管理后台地址（由 baseUrl 去掉 /api 再加 /admin/ 得到）
  static String get adminUrl => '${baseUrl.replaceFirst(RegExp(r'/api/?$'), '')}/admin/';

  late final Dio dio = Dio(BaseOptions(baseUrl: baseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
