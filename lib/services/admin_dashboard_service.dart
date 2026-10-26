import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_dashboard.dart';

class AdminDashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AdminDashboardStats> getStats() async {
    final data = await _client.rpc('get_admin_dashboard_stats');
    return AdminDashboardStats.fromMap(Map<String, dynamic>.from(data as Map));
  }
}
