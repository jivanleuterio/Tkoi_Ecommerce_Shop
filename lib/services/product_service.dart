import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';

class ProductService {
  static const String productSelect =
      '*, product_images(image_url, sort_order), shops(name, location, logo_url, owner_id)';

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Product>> getProducts({
    String? search,
    String? category,
    String? shopId,
    String? sellerId,
    bool sellerView = false,
    int? limit,
  }) async {
    var query = _client.from('products').select(productSelect);
    if (search != null && search.trim().isNotEmpty) {
      final safeSearch = search.trim().replaceAll(',', ' ');
      query = query.or('name.ilike.%$safeSearch%,species.ilike.%$safeSearch%');
    }
    if (category != null && category != 'All') {
      query = query.eq('category', category);
    }
    if (shopId != null) query = query.eq('shop_id', shopId);
    if (sellerId != null) query = query.eq('seller_id', sellerId);
    if (!sellerView) {
      query = query.eq('status', 'available').gt('quantity', 0);
    }

    var ordered = query.order('created_at', ascending: false);
    if (limit != null) ordered = ordered.limit(limit);
    final data = await ordered;
    return _attachMarketplaceData(data.map(Product.fromMap).toList());
  }

  Future<List<Product>> getProductsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final data = await _client
        .from('products')
        .select(productSelect)
        .inFilter('id', ids)
        .eq('status', 'available')
        .gt('quantity', 0);
    final byId = {
      for (final product in await _attachMarketplaceData(
        data.map(Product.fromMap).toList(),
      ))
        product.id: product,
    };
    return [for (final id in ids) ?byId[id]];
  }

  Future<Product> getProduct(String id) async {
    final data = await _client
        .from('products')
        .select(productSelect)
        .eq('id', id)
        .single();
    final products = await _attachMarketplaceData([Product.fromMap(data)]);
    return products.single;
  }

  Future<List<Product>> _attachMarketplaceData(List<Product> products) async {
    final withFavorites = await _attachFavoriteState(products);
    return _attachStats(withFavorites);
  }

  Future<List<Product>> _attachStats(List<Product> products) async {
    if (products.isEmpty) return products;
    try {
      final rows = await _client.rpc(
        'get_product_stats',
        params: {
          'p_product_ids': products.map((product) => product.id).toList(),
        },
      );
      final stats = <String, Map<String, dynamic>>{
        for (final row in (rows as List).whereType<Map<String, dynamic>>())
          row['product_id'] as String: row,
      };
      return [
        for (final product in products)
          if (stats[product.id] case final row?)
            product.copyWith(
              soldCount: (row['sold_count'] as num? ?? 0).toInt(),
              heartCount: (row['heart_count'] as num? ?? 0).toInt(),
              averageRating: (row['average_rating'] as num? ?? 0).toDouble(),
              totalReviews: (row['total_reviews'] as num? ?? 0).toInt(),
              ratingCounts: {
                5: (row['rating_5'] as num? ?? 0).toInt(),
                4: (row['rating_4'] as num? ?? 0).toInt(),
                3: (row['rating_3'] as num? ?? 0).toInt(),
                2: (row['rating_2'] as num? ?? 0).toInt(),
                1: (row['rating_1'] as num? ?? 0).toInt(),
              },
            )
          else
            product,
      ];
    } on PostgrestException catch (error) {
      if (error.code == '42883' ||
          error.code == 'PGRST202' ||
          error.code == 'PGRST205') {
        return products;
      }
      rethrow;
    }
  }

  Future<List<Product>> _attachFavoriteState(List<Product> products) async {
    if (products.isEmpty || _client.auth.currentUser == null) return products;
    try {
      final rows = await _client
          .from('product_favorites')
          .select('product_id')
          .eq('buyer_id', _client.auth.currentUser!.id)
          .inFilter(
            'product_id',
            products.map((product) => product.id).toList(),
          );
      final favoriteIds = rows
          .map((row) => row['product_id'] as String?)
          .whereType<String>()
          .toSet();
      return [
        for (final product in products)
          product.copyWith(isFavorite: favoriteIds.contains(product.id)),
      ];
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') return products;
      rethrow;
    }
  }

  Future<Product> saveProduct({
    String? id,
    required String shopId,
    required Map<String, dynamic> values,
    List<String> newImageUrls = const [],
  }) async {
    final sellerId = _client.auth.currentUser?.id;
    if (sellerId == null) throw Exception('Please sign in again.');

    final record = {...values, 'shop_id': shopId, 'seller_id': sellerId};
    final Map<String, dynamic> saved;
    if (id == null) {
      saved = await _client.from('products').insert(record).select().single();
      id = saved['id'] as String;
    } else {
      saved = await _client
          .from('products')
          .update(record)
          .eq('id', id)
          .select()
          .single();
    }

    if (newImageUrls.isNotEmpty) {
      await _client.from('product_images').insert([
        for (var index = 0; index < newImageUrls.length; index++)
          {
            'product_id': id,
            'image_url': newImageUrls[index],
            'sort_order': index,
          },
      ]);
    }
    return getProduct(id);
  }

  Future<void> updateStatus(String id, String status) async {
    await _client.from('products').update({'status': status}).eq('id', id);
  }

  Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }
}
