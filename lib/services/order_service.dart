import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market_order.dart';

class OrderService {
  static const String orderSelect =
      '*, shops(name), order_items(id, product_id, product_name, quantity, unit_price, image_url)';

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<MarketOrder>> getMyOrders() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Please sign in again.');
    final data = await _client
        .from('orders')
        .select(orderSelect)
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);
    final orders = data.map(MarketOrder.fromMap).toList();
    return _attachAftercare(orders, buyerId: userId);
  }

  Future<List<MarketOrder>> getSellerOrders(String shopId) async {
    try {
      final rows = await _client.rpc(
        'get_seller_orders_secure',
        params: {'p_shop_id': shopId},
      );
      final orders = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(MarketOrder.fromMap)
          .toList();
      return await _attachAftercare(orders, shopId: shopId);
    } on PostgrestException catch (error) {
      if (error.code != '42883' && error.code != 'PGRST202') rethrow;
      final data = await _client
          .from('orders')
          .select(orderSelect)
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      final orders = data.map(MarketOrder.fromMap).toList();
      return _attachAftercare(orders, shopId: shopId);
    }
  }

  Future<List<MarketOrder>> _attachAftercare(
    List<MarketOrder> orders, {
    String? buyerId,
    String? shopId,
  }) async {
    if (orders.isEmpty) return orders;
    try {
      var reviewQuery = _client.from('order_reviews').select();
      var returnQuery = _client.from('order_returns').select();
      if (buyerId != null) {
        reviewQuery = reviewQuery.eq('buyer_id', buyerId);
        returnQuery = returnQuery.eq('buyer_id', buyerId);
      }
      if (shopId != null) {
        reviewQuery = reviewQuery.eq('shop_id', shopId);
        returnQuery = returnQuery.eq('shop_id', shopId);
      }
      final results = await Future.wait([reviewQuery, returnQuery]);
      final reviews = <String, OrderReview>{
        for (final row in results[0])
          row['order_id'] as String: OrderReview.fromMap(row),
      };
      final returns = <String, OrderReturnRequest>{
        for (final row in results[1])
          row['order_id'] as String: OrderReturnRequest.fromMap(row),
      };
      final withAftercare = orders
          .map(
            (order) => order.copyWith(
              review: reviews[order.id],
              returnRequest: returns[order.id],
            ),
          )
          .toList();
      return await _attachProductReviewState(withAftercare, buyerId: buyerId);
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') return orders;
      rethrow;
    }
  }

  Future<List<MarketOrder>> _attachProductReviewState(
    List<MarketOrder> orders, {
    String? buyerId,
  }) async {
    if (orders.isEmpty || buyerId == null) return orders;
    try {
      final rows = await _client
          .from('product_reviews')
          .select('order_item_id')
          .eq('buyer_id', buyerId);
      final reviewedIds = rows
          .map((row) => row['order_item_id'] as String?)
          .whereType<String>()
          .toSet();
      return [
        for (final order in orders)
          order.copyWith(
            items: [
              for (final item in order.items)
                item.copyWith(reviewed: reviewedIds.contains(item.id)),
            ],
          ),
      ];
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') return orders;
      rethrow;
    }
  }

  Future<void> placeOrder(String deliveryAddress) async {
    await _client.rpc(
      'place_order',
      params: {'p_delivery_address': deliveryAddress.trim()},
    );
  }

  Future<void> buyNow({
    required String productId,
    required int quantity,
    required String deliveryAddress,
  }) async {
    await _client.rpc(
      'buy_now',
      params: {
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_delivery_address': deliveryAddress.trim(),
      },
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await _client.rpc('cancel_order', params: {'p_order_id': orderId});
  }

  Future<void> updateStatus(String orderId, String status) async {
    await _client.rpc(
      'update_order_status',
      params: {'p_order_id': orderId, 'p_status': status},
    );
  }

  Future<void> markReceived(String orderId) async {
    await _client.rpc('mark_order_received', params: {'p_order_id': orderId});
  }

  Future<void> submitReview({
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    await _client.rpc(
      'submit_order_review',
      params: {
        'p_order_id': orderId,
        'p_rating': rating,
        'p_comment': comment.trim(),
      },
    );
  }

  Future<void> requestReturn({
    required String orderId,
    required String reason,
    required String details,
  }) async {
    await _client.rpc(
      'request_order_return',
      params: {
        'p_order_id': orderId,
        'p_reason': reason,
        'p_details': details.trim(),
      },
    );
  }

  Future<void> cancelReturn(String returnId) async {
    await _client.rpc('cancel_order_return', params: {'p_return_id': returnId});
  }

  Future<void> updateReturnStatus(String returnId, String status) async {
    await _client.rpc(
      'update_return_status',
      params: {'p_return_id': returnId, 'p_status': status},
    );
  }
}
