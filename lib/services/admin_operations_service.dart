import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_operations.dart';
import '../models/seller_wallet.dart';

class AdminOperationsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<AdminOrderSummary>> getOrders({
    String? status,
    String? search,
  }) async {
    final rows = await _client.rpc(
      'admin_list_orders',
      params: {'p_status': status, 'p_search': search},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminOrderSummary.fromMap)
        .toList();
  }

  Future<Map<String, dynamic>> getOrder(String id) async {
    final data = await _client.rpc(
      'admin_get_order_detail',
      params: {'p_order_id': id},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<String> revealAddress(String id, String reason) async =>
      await _client.rpc(
        'admin_reveal_order_address',
        params: {'p_order_id': id, 'p_reason': reason.trim()},
      ) as String;

  Future<List<AdminReturnRequest>> getReturns({String? status}) async {
    final rows = await _client.rpc(
      'admin_list_returns',
      params: {'p_status': status},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminReturnRequest.fromMap)
        .toList();
  }

  Future<void> decideReturn({
    required String id,
    required String status,
    required String note,
    required String reason,
  }) => _client.rpc(
    'admin_decide_return',
    params: {
      'p_return_id': id,
      'p_status': status,
      'p_note': note.trim(),
      'p_reason': reason.trim(),
    },
  );

  Future<List<AdminWithdrawal>> getWithdrawals({String? status}) async {
    final rows = await _client.rpc(
      'admin_list_withdrawals',
      params: {'p_status': status},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminWithdrawal.fromMap)
        .toList();
  }

  Future<void> processWithdrawal({
    required String id,
    required String action,
    required String note,
    String? reference,
    required String reason,
  }) => _client.rpc(
    'admin_process_withdrawal_authenticated',
    params: {
      'p_withdrawal_id': id,
      'p_action': action,
      'p_admin_note': note.trim(),
      'p_external_reference': reference?.trim(),
      'p_reason': reason.trim(),
    },
  );

  Future<Map<String, dynamic>> revealWithdrawal(
    String id,
    String reason,
  ) async {
    final data = await _client.rpc(
      'admin_reveal_withdrawal_account',
      params: {'p_withdrawal_id': id, 'p_reason': reason.trim()},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<AdminWalletSummary>> getWallets() async {
    final rows = await _client.rpc('admin_list_wallets');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminWalletSummary.fromMap)
        .toList();
  }

  Future<List<SellerWalletTransaction>> getLedger(String shopId) async {
    final rows = await _client.rpc(
      'admin_get_wallet_ledger',
      params: {'p_shop_id': shopId},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(SellerWalletTransaction.fromMap)
        .toList();
  }

  Future<AdminMarketplaceSettings> getSettings() async {
    final data = await _client.rpc('get_admin_marketplace_settings');
    return AdminMarketplaceSettings.fromMap(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<void> updateSettings({
    required String fee,
    required String minimum,
    required int days,
    required bool demoMode,
    required String reason,
  }) => _client.rpc(
    'admin_update_marketplace_settings',
    params: {
      'p_platform_fee_percent': fee,
      'p_minimum_withdrawal': minimum,
      'p_auto_release_days': days,
      'p_demo_mode': demoMode,
      'p_reason': reason.trim(),
    },
  );

  Future<List<AdminAuditEntry>> getAudit({String? action}) async {
    final rows = await _client.rpc(
      'admin_list_audit_log',
      params: {'p_action': action, 'p_admin_id': null, 'p_target_type': null},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(AdminAuditEntry.fromMap)
        .toList();
  }
}
