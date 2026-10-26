class AdminAccessContext {
  final String userId;
  final String status;
  final String? role;
  final Set<String> permissions;
  final String? reasonPublic;
  final DateTime? restrictedUntil;

  const AdminAccessContext({
    required this.userId,
    required this.status,
    required this.role,
    required this.permissions,
    this.reasonPublic,
    this.restrictedUntil,
  });

  bool get isAdmin => role != null;
  bool get isBanned => status == 'banned';
  bool get isSuspended => status == 'suspended';

  bool hasPermission(String permission) {
    if (permissions.contains('*') || permissions.contains(permission)) {
      return true;
    }
    final separator = permission.indexOf('.');
    if (separator < 0) return false;
    return permissions.contains('${permission.substring(0, separator)}.*');
  }

  factory AdminAccessContext.fromMap(Map<String, dynamic> map) {
    final rawPermissions = map['permissions'] as List? ?? const [];
    return AdminAccessContext(
      userId: map['user_id'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      role: map['role'] as String?,
      permissions: rawPermissions.whereType<String>().toSet(),
      reasonPublic: map['reason_public'] as String?,
      restrictedUntil: DateTime.tryParse(
        map['restricted_until'] as String? ?? '',
      ),
    );
  }
}

enum AccessDestination { restricted, admin, marketplace }

AccessDestination resolveAccessDestination(AdminAccessContext access) {
  if (access.isBanned) return AccessDestination.restricted;
  if (access.isAdmin) return AccessDestination.admin;
  return AccessDestination.marketplace;
}

class AdminTeamMember {
  final String userId;
  final String role;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final DateTime grantedAt;

  const AdminTeamMember({
    required this.userId,
    required this.role,
    required this.fullName,
    required this.username,
    this.avatarUrl,
    required this.grantedAt,
  });

  factory AdminTeamMember.fromMap(Map<String, dynamic> map) => AdminTeamMember(
    userId: map['user_id'] as String,
    role: map['role'] as String? ?? 'moderator',
    fullName: map['full_name'] as String? ?? 'Tkoi admin',
    username: map['username'] as String? ?? '',
    avatarUrl: map['avatar_url'] as String?,
    grantedAt:
        DateTime.tryParse(map['granted_at'] as String? ?? '') ?? DateTime.now(),
  );
}
