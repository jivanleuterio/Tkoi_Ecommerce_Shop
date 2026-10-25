import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/models/seller_payout.dart';

void main() {
  test('demo paid withdrawal is clearly labelled', () {
    final withdrawal = SellerWithdrawal.fromMap({
      'id': 'demo-id',
      'amount': '125.50',
      'payout_method': 'gcash',
      'account_name_snapshot': 'Demo Seller',
      'account_number_snapshot': '09171234567',
      'status': 'paid',
      'is_demo': true,
      'requested_at': '2026-10-26T00:00:00Z',
    });

    expect(withdrawal.amountCentavos, 12550);
    expect(withdrawal.isDemo, isTrue);
    expect(withdrawal.statusLabel, 'Demo paid');
  });
}
