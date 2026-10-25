import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/seller_payout.dart';

class SellerPayoutService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<SellerPayoutAccount>> getAccounts(String shopId) async {
    final rows = await _client.rpc(
      'get_seller_payout_accounts',
      params: {'p_shop_id': shopId},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(SellerPayoutAccount.fromMap)
        .toList();
  }

  Future<void> saveDemoAccount({
    required String shopId,
    String? accountId,
    required String method,
    required String accountName,
    required String accountNumber,
    String? bankName,
    required bool isDefault,
  }) async {
    await _client.rpc(
      'save_demo_seller_payout_account',
      params: {
        'p_shop_id': shopId,
        'p_account_id': accountId,
        'p_method': method,
        'p_account_name': accountName.trim(),
        'p_account_number': accountNumber.trim(),
        'p_bank_name': bankName?.trim(),
        'p_is_default': isDefault,
      },
    );
  }

  Future<void> deleteAccount(String accountId) => _client.rpc(
    'delete_seller_payout_account',
    params: {'p_account_id': accountId},
  );

  Future<List<SellerWithdrawal>> getWithdrawals(String shopId) async {
    final rows = await _client.rpc(
      'get_seller_withdrawals',
      params: {'p_shop_id': shopId},
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(SellerWithdrawal.fromMap)
        .toList();
  }

  Future<void> requestWithdrawal({
    required String shopId,
    required String amount,
    required String payoutAccountId,
  }) => _client.rpc(
    'request_seller_withdrawal',
    params: {
      'p_shop_id': shopId,
      'p_amount': amount,
      'p_payout_account_id': payoutAccountId,
    },
  );

  Future<void> requestDemoWithdrawal({
    required String shopId,
    required String amount,
    required String payoutAccountId,
  }) => _client.rpc(
    'request_demo_seller_withdrawal',
    params: {
      'p_shop_id': shopId,
      'p_amount': amount,
      'p_payout_account_id': payoutAccountId,
    },
  );

  Future<void> cancelWithdrawal(String withdrawalId) => _client.rpc(
    'cancel_seller_withdrawal',
    params: {'p_withdrawal_id': withdrawalId},
  );
}
