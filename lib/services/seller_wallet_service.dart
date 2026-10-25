import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/seller_wallet.dart';

class SellerWalletService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<SellerWalletSummary> getSummary(String shopId) async {
    final rows = await _client.rpc(
      'get_seller_wallet_summary',
      params: {'p_shop_id': shopId},
    );
    final list = (rows as List).whereType<Map<String, dynamic>>().toList();
    return list.isEmpty
        ? SellerWalletSummary.empty
        : SellerWalletSummary.fromMap(list.first);
  }

  Future<List<SellerWalletTransaction>> getTransactions(
    String shopId, {
    String filter = 'all',
  }) async {
    final rows = await _client.rpc(
      'get_seller_wallet_transactions',
      params: {'p_shop_id': shopId, 'p_filter': filter},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(SellerWalletTransaction.fromMap)
        .toList();
  }
}
