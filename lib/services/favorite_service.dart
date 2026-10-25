import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import 'product_service.dart';

class FavoriteService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in again.');
    return id;
  }

  Future<void> setFavorite(String productId, bool favorite) async {
    if (favorite) {
      await _client.from('product_favorites').upsert({
        'buyer_id': _userId,
        'product_id': productId,
      });
    } else {
      await _client
          .from('product_favorites')
          .delete()
          .eq('buyer_id', _userId)
          .eq('product_id', productId);
    }
  }

  Future<List<Product>> getFavorites() async {
    final rows = await _client
        .from('product_favorites')
        .select('product_id')
        .eq('buyer_id', _userId)
        .order('created_at', ascending: false);
    final ids = rows
        .map((row) => row['product_id'] as String?)
        .whereType<String>()
        .toList();
    return ProductService().getProductsByIds(ids);
  }
}
