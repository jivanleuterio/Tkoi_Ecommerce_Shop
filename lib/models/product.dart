class Product {
  final String id;
  final String shopId;
  final String sellerId;
  final String name;
  final String species;
  final String category;
  final String description;
  final double price;
  final int quantity;
  final String size;
  final int? ageMonths;
  final String sex;
  final String healthCondition;
  final String sellerLocation;
  final String status;
  final String moderationStatus;
  final String moderationReason;
  final DateTime createdAt;
  final List<String> imageUrls;
  final String shopName;
  final bool isFavorite;
  final int soldCount;
  final int heartCount;
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingCounts;

  const Product({
    required this.id,
    required this.shopId,
    required this.sellerId,
    required this.name,
    required this.species,
    required this.category,
    required this.description,
    required this.price,
    required this.quantity,
    required this.size,
    required this.ageMonths,
    required this.sex,
    required this.healthCondition,
    required this.sellerLocation,
    required this.status,
    this.moderationStatus = 'clear',
    this.moderationReason = '',
    required this.createdAt,
    required this.imageUrls,
    required this.shopName,
    this.isFavorite = false,
    this.soldCount = 0,
    this.heartCount = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.ratingCounts = const {},
  });

  bool get isAvailable =>
      status == 'available' && quantity > 0 && moderationStatus == 'clear';
  bool get isModerated => moderationStatus != 'clear';
  String? get primaryImage => imageUrls.isEmpty ? null : imageUrls.first;

  Product copyWith({
    bool? isFavorite,
    int? soldCount,
    int? heartCount,
    double? averageRating,
    int? totalReviews,
    Map<int, int>? ratingCounts,
  }) => Product(
    id: id,
    shopId: shopId,
    sellerId: sellerId,
    name: name,
    species: species,
    category: category,
    description: description,
    price: price,
    quantity: quantity,
    size: size,
    ageMonths: ageMonths,
    sex: sex,
    healthCondition: healthCondition,
    sellerLocation: sellerLocation,
    status: status,
    moderationStatus: moderationStatus,
    moderationReason: moderationReason,
    createdAt: createdAt,
    imageUrls: imageUrls,
    shopName: shopName,
    isFavorite: isFavorite ?? this.isFavorite,
    soldCount: soldCount ?? this.soldCount,
    heartCount: heartCount ?? this.heartCount,
    averageRating: averageRating ?? this.averageRating,
    totalReviews: totalReviews ?? this.totalReviews,
    ratingCounts: ratingCounts ?? this.ratingCounts,
  );

  factory Product.fromMap(Map<String, dynamic> map) {
    final rawImages = map['product_images'] as List? ?? const [];
    final images = rawImages.whereType<Map<String, dynamic>>().toList()
      ..sort(
        (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
          (b['sort_order'] as num?) ?? 0,
        ),
      );
    final rawShop = map['shops'];
    final shop = rawShop is Map<String, dynamic> ? rawShop : null;

    return Product(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      sellerId: map['seller_id'] as String,
      name: map['name'] as String? ?? 'Unnamed fish',
      species: map['species'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num? ?? 0).toDouble(),
      quantity: (map['quantity'] as num? ?? 0).toInt(),
      size: map['size'] as String? ?? '',
      ageMonths: (map['age_months'] as num?)?.toInt(),
      sex: map['sex'] as String? ?? 'Unknown',
      healthCondition: map['health_condition'] as String? ?? '',
      sellerLocation: map['seller_location'] as String? ?? '',
      status: map['status'] as String? ?? 'hidden',
      moderationStatus: map['moderation_status'] as String? ?? 'clear',
      moderationReason: map['moderation_reason'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      imageUrls: images
          .map((image) => image['image_url'] as String? ?? '')
          .where((url) => url.isNotEmpty)
          .toList(),
      shopName: shop?['name'] as String? ?? 'Fish Shop',
    );
  }
}
