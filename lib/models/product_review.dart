class ProductReviewImage {
  final String url;
  final int sortOrder;

  const ProductReviewImage({required this.url, required this.sortOrder});

  factory ProductReviewImage.fromMap(Map<String, dynamic> map) =>
      ProductReviewImage(
        url: map['url'] as String? ?? '',
        sortOrder: (map['sort_order'] as num? ?? 0).toInt(),
      );
}

class ProductReview {
  final String id;
  final String orderItemId;
  final String productId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String buyerName;
  final String? buyerAvatar;
  final List<ProductReviewImage> images;

  const ProductReview({
    required this.id,
    required this.orderItemId,
    required this.productId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.buyerName,
    this.buyerAvatar,
    required this.images,
  });

  factory ProductReview.fromMap(Map<String, dynamic> map) {
    final images =
        (map['images'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ProductReviewImage.fromMap)
            .where((image) => image.url.isNotEmpty)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ProductReview(
      id: map['id'] as String,
      orderItemId: map['order_item_id'] as String,
      productId: map['product_id'] as String,
      rating: (map['rating'] as num? ?? 0).toInt(),
      comment: map['comment'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      buyerName: map['buyer_name'] as String? ?? 'Tkoi buyer',
      buyerAvatar: map['buyer_avatar'] as String?,
      images: images,
    );
  }
}
