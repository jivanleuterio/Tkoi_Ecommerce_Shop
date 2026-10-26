import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_access.dart';

class AdminAccessService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AdminAccessContext> getMyContext() async {
    final data = await _client.rpc('get_my_access_context');
    return AdminAccessContext.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<List<AdminTeamMember>> getTeam() async {
    final rows = await _client.rpc('get_admin_team');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminTeamMember.fromMap)
        .toList();
  }
}
