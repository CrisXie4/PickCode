// 数据模型

class AppUser {
  final String id;
  final String? phone;
  final String? email;
  final String nickname;
  final String? avatarUrl;
  final bool isAdmin;

  AppUser({
    required this.id,
    this.phone,
    this.email,
    required this.nickname,
    this.avatarUrl,
    this.isAdmin = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        phone: j['phone'],
        email: j['email'],
        nickname: j['nickname'] ?? '',
        avatarUrl: j['avatarUrl'],
        isAdmin: j['isAdmin'] ?? false,
      );
}

class Parcel {
  final String id;
  final String? company;
  final String pickupCode;
  final String? locker;
  final String? location;
  final String? recipient;
  final String? note;
  final String status; // pending / picked / expired
  final DateTime? createdAt;

  Parcel({
    required this.id,
    this.company,
    required this.pickupCode,
    this.locker,
    this.location,
    this.recipient,
    this.note,
    required this.status,
    this.createdAt,
  });

  factory Parcel.fromJson(Map<String, dynamic> j) => Parcel(
        id: j['id'],
        company: j['company'],
        pickupCode: j['pickupCode'] ?? '',
        locker: j['locker'],
        location: j['location'],
        recipient: j['recipient'],
        note: j['note'],
        status: j['status'] ?? 'pending',
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString())?.toLocal() : null,
      );

  static const statusLabels = {
    'pending': '待取件',
    'picked': '已取件',
    'expired': '已过期',
  };
}

/// 智能识别解析结果
class ParsedExpress {
  final String? company;
  final String? pickupCode;
  final String? locker;
  final String? location;
  final double confidence;

  ParsedExpress({this.company, this.pickupCode, this.locker, this.location, this.confidence = 0});

  factory ParsedExpress.fromJson(Map<String, dynamic> j) => ParsedExpress(
        company: j['company'],
        pickupCode: j['pickupCode'],
        locker: j['locker'],
        location: j['location'],
        confidence: (j['confidence'] ?? 0).toDouble(),
      );
}

class Group {
  final String id;
  final String name;
  final String inviteCode;
  final String? role;
  final int memberCount;

  Group({required this.id, required this.name, required this.inviteCode, this.role, this.memberCount = 0});

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'],
        name: j['name'],
        inviteCode: j['inviteCode'] ?? '',
        role: j['role'],
        memberCount: j['memberCount'] ?? 0,
      );
}
