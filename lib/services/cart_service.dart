import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import 'product_service.dart';

class CartService {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final SupabaseClient _client = Supabase.instance.client;

  static void notifyChanged() {
    revision.value++;
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in again.');
    return id;
  }

  Future<List<CartItem>> getCart() async {
    final data = await _client
        .from('cart_items')
        .select('id, quantity, products(${ProductService.productSelect})')
        .eq('buyer_id', _userId)
        .order('created_at');
    return data.map(CartItem.fromMap).toList();
  }

  Future<void> add(Product product, {int quantity = 1}) async {
    if (product.sellerId == _userId) {
      throw Exception('You cannot buy your own listing.');
    }
    if (!product.isAvailable || quantity > product.quantity) {
      throw Exception('The requested quantity is not available.');
    }

    await _client.rpc(
      'add_to_cart',
      params: {'p_product_id': product.id, 'p_quantity': quantity},
    );
    notifyChanged();
  }

  Future<void> updateQuantity(String id, int quantity) async {
    if (quantity < 1) throw Exception('Quantity must be at least 1.');
    await _client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', id);
    notifyChanged();
  }

  Future<void> remove(String id) async {
    await _client.from('cart_items').delete().eq('id', id);
    notifyChanged();
  }
}
