import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/models/market_order.dart';

Map<String, dynamic> completedOrder(DateTime completedAt) => {
  'id': 'order-id',
  'buyer_id': 'buyer-id',
  'seller_id': 'seller-id',
  'shop_id': 'shop-id',
  'shop_name': 'Test shop',
  'status': 'completed',
  'total': 100,
  'delivery_address': 'Test address',
  'payment_method': 'Cash on Delivery',
  'payment_status': 'not_required',
  'created_at': completedAt.subtract(const Duration(days: 2)).toIso8601String(),
  'completed_at': completedAt.toIso8601String(),
  'order_items': <Map<String, dynamic>>[],
};

void main() {
  test('return window remains open for less than 24 hours', () {
    final order = MarketOrder.fromMap(
      completedOrder(DateTime.now().subtract(const Duration(hours: 23))),
    );
    expect(order.isReturnWindowOpen, isTrue);
  });

  test('return window closes after 24 hours', () {
    final order = MarketOrder.fromMap(
      completedOrder(DateTime.now().subtract(const Duration(hours: 25))),
    );
    expect(order.isReturnWindowOpen, isFalse);
  });
}
