import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/seller_dashboard_stats.dart';

class SellerDashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<SellerDashboardStats?> getStats(String shopId, {int days = 7}) async {
    try {
      final data = await _client.rpc(
        'get_seller_dashboard_stats',
        params: {'p_shop_id': shopId, 'p_days': days},
      );
      return data is Map<String, dynamic>
          ? SellerDashboardStats.fromMap(data)
          : null;
    } on PostgrestException catch (error) {
      if (error.code == '42883' || error.code == 'PGRST202') return null;
      rethrow;
    }
  }
}
