import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_user.dart';

class AdminModerationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<AdminUserSummary>> getUsers({
    String? search,
    String? status,
    String? role,
    bool? hasShop,
  }) async {
    final rows = await _client.rpc(
      'admin_list_users',
      params: {
        'p_search': search,
        'p_status': status,
        'p_role': role,
        'p_has_shop': hasShop,
      },
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminUserSummary.fromMap)
        .toList();
  }

  Future<AdminUserDetail> getUser(String userId) async {
    final data = await _client.rpc(
      'admin_get_user_detail',
      params: {'p_user_id': userId},
    );
    return AdminUserDetail(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> revealContact({
    required String userId,
    required String reason,
  }) async {
    final data = await _client.rpc(
      'admin_reveal_user_contact',
      params: {'p_user_id': userId, 'p_reason': reason.trim()},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<AdminModerationResult> setStatus({
    required String userId,
    required String status,
    DateTime? restrictedUntil,
    required String publicReason,
    required String internalReason,
    required String auditReason,
  }) async {
    await _client.rpc(
      'admin_set_account_control',
      params: {
        'p_user_id': userId,
        'p_status': status,
        'p_suspended_until': restrictedUntil?.toUtc().toIso8601String(),
        'p_reason_public': publicReason.trim(),
        'p_reason_internal': internalReason.trim(),
        'p_reason': auditReason.trim(),
      },
    );
    try {
      final response = await _client.functions.invoke(
        'admin-set-auth-ban',
        body: {
          'user_id': userId,
          'status': status,
          'restricted_until': restrictedUntil?.toUtc().toIso8601String(),
        },
      );
      final data = response.data;
      return AdminModerationResult(
        authWarning: data is Map ? data['warning'] as String? : null,
      );
    } catch (_) {
      return const AdminModerationResult(
        authWarning: 'The database restriction is active, but Supabase Auth could not be updated. Deploy admin-set-auth-ban and check its secrets.',
      );
    }
  }
}
