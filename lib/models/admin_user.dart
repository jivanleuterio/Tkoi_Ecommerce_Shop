class AdminUserSummary {
  final String userId;
  final String fullName;
  final String username;
  final String maskedEmail;
  final String maskedPhone;
  final String? avatarUrl;
  final String status;
  final DateTime? restrictedUntil;
  final String? role;
  final bool isShopOwner;
  final int orderCount;
  final int reportCount;
  final DateTime createdAt;

  const AdminUserSummary({
    required this.userId,
    required this.fullName,
    required this.username,
    required this.maskedEmail,
    required this.maskedPhone,
    this.avatarUrl,
    required this.status,
    this.restrictedUntil,
    this.role,
    required this.isShopOwner,
    required this.orderCount,
    required this.reportCount,
    required this.createdAt,
  });

  factory AdminUserSummary.fromMap(Map<String, dynamic> map) =>
      AdminUserSummary(
        userId: map['user_id'] as String,
        fullName: map['full_name'] as String? ?? 'Tkoi user',
        username: map['username'] as String? ?? '',
        maskedEmail: map['masked_email'] as String? ?? '***',
        maskedPhone: map['masked_phone'] as String? ?? '***',
        avatarUrl: map['avatar_url'] as String?,
        status: map['status'] as String? ?? 'active',
        restrictedUntil: DateTime.tryParse(
          map['restricted_until'] as String? ?? '',
        ),
        role: map['role'] as String?,
        isShopOwner: map['is_shop_owner'] as bool? ?? false,
        orderCount: (map['order_count'] as num? ?? 0).toInt(),
        reportCount: (map['report_count'] as num? ?? 0).toInt(),
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AdminUserDetail {
  final Map<String, dynamic> data;

  const AdminUserDetail(this.data);

  String get userId => data['user_id'] as String;
  String get fullName => data['full_name'] as String? ?? 'Tkoi user';
  String get username => data['username'] as String? ?? '';
  String get maskedEmail => data['masked_email'] as String? ?? '***';
  String get maskedPhone => data['masked_phone'] as String? ?? '***';
  String get status => data['status'] as String? ?? 'active';
  String? get role => data['role'] as String?;
  String? get reasonPublic => data['reason_public'] as String?;
  DateTime? get restrictedUntil =>
      DateTime.tryParse(data['restricted_until'] as String? ?? '');
  int get orderCount => (data['order_count'] as num? ?? 0).toInt();
  Map<String, dynamic>? get shop => data['shop'] is Map
      ? Map<String, dynamic>.from(data['shop'] as Map)
      : null;
  List<Map<String, dynamic>> get history =>
      (data['status_history'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
}

class AdminModerationResult {
  final String? authWarning;

  const AdminModerationResult({this.authWarning});
}
