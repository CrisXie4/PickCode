import 'models_import.dart';

/// 封装所有后端接口调用
class ApiService {
  final _dio = ApiClient.instance.dio;

  // ---- Auth ----
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async =>
      (await _dio.post('/auth/register', data: body)).data;

  Future<Map<String, dynamic>> login(String account, String password) async =>
      (await _dio.post('/auth/login', data: {'account': account, 'password': password})).data;

  // ---- User ----
  Future<AppUser> me() async => AppUser.fromJson((await _dio.get('/users/me')).data['user']);

  Future<AppUser> updateProfile(Map<String, dynamic> body) async =>
      AppUser.fromJson((await _dio.patch('/users/me', data: body)).data['user']);

  // ---- Parcels ----
  Future<List<Parcel>> myParcels() async {
    final data = (await _dio.get('/parcels')).data['parcels'] as List;
    return data.map((e) => Parcel.fromJson(e)).toList();
  }

  Future<Parcel> addParcel(Map<String, dynamic> body) async =>
      Parcel.fromJson((await _dio.post('/parcels', data: body)).data['parcel']);

  Future<void> updateParcel(String id, Map<String, dynamic> body) async =>
      _dio.patch('/parcels/$id', data: body);

  Future<void> deleteParcel(String id) async => _dio.delete('/parcels/$id');

  Future<void> shareToGroup(String parcelId, String groupId, {String? note}) async =>
      _dio.post('/parcels/$parcelId/share', data: {'groupId': groupId, 'note': note});

  // ---- 智能识别 ----
  Future<ParsedExpress> parse(String text) async =>
      ParsedExpress.fromJson((await _dio.post('/recognition/parse', data: {'text': text})).data['parsed']);

  // ---- Groups ----
  Future<List<Group>> myGroups() async {
    final data = (await _dio.get('/groups')).data['groups'] as List;
    return data.map((e) => Group.fromJson(e)).toList();
  }

  Future<Group> createGroup(String name) async =>
      Group.fromJson((await _dio.post('/groups', data: {'name': name})).data['group']);

  Future<Map<String, dynamic>> groupDetail(String id) async => (await _dio.get('/groups/$id')).data;

  Future<void> joinByCode(String code, {String? message}) async =>
      _dio.post('/groups/join', data: {'inviteCode': code, 'message': message});

  Future<List<dynamic>> joinRequests(String groupId) async =>
      (await _dio.get('/groups/$groupId/requests')).data['requests'];

  Future<void> reviewRequest(String groupId, String requestId, String action) async =>
      _dio.post('/groups/$groupId/requests/$requestId', data: {'action': action});

  Future<void> removeMember(String groupId, String userId) async =>
      _dio.delete('/groups/$groupId/members/$userId');

  Future<void> toggleNotify(String groupId, bool enabled) async =>
      _dio.patch('/groups/$groupId/notify', data: {'enabled': enabled});

  // 手动提醒某条群内共享快递
  Future<void> remindShared(String groupId, String sharedId) async =>
      _dio.post('/groups/$groupId/shared/$sharedId/remind');

  // 标记已取件（通知发起人 + 自动清除该共享记录）
  Future<void> markSharedPicked(String groupId, String sharedId) async =>
      _dio.post('/groups/$groupId/shared/$sharedId/picked');

  // 注册推送设备 token
  Future<void> registerDeviceToken(String token, String platform) async =>
      _dio.post('/users/device-token', data: {'token': token, 'platform': platform});

  // ---- Notifications ----
  Future<Map<String, dynamic>> notifications() async => (await _dio.get('/notifications')).data;
  Future<void> markRead({String? id}) async => _dio.post('/notifications/read', data: {'id': id});
}
