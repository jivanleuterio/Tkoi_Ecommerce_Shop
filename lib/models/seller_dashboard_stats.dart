import '../widgets/seller_sales_chart.dart';
import 'seller_wallet.dart';

class SellerTopProduct {
  final String productId;
  final String name;
  final int soldCount;
  final String? imageUrl;

  const SellerTopProduct({
    required this.productId,
    required this.name,
    required this.soldCount,
    required this.imageUrl,
  });

  factory SellerTopProduct.fromMap(Map<String, dynamic> map) =>
      SellerTopProduct(
        productId: map['product_id'] as String,
        name: map['name'] as String? ?? 'Fish',
        soldCount: (map['sold_count'] as num? ?? 0).toInt(),
        imageUrl: map['image_url'] as String?,
      );
}

class SellerRecentReview {
  final String buyerName;
  final String productName;
  final int rating;
  final String comment;

  const SellerRecentReview({
    required this.buyerName,
    required this.productName,
    required this.rating,
    required this.comment,
  });

  factory SellerRecentReview.fromMap(Map<String, dynamic> map) =>
      SellerRecentReview(
        buyerName: map['buyer_name'] as String? ?? 'Tkoi buyer',
        productName: map['product_name'] as String? ?? 'Fish',
        rating: (map['rating'] as num? ?? 0).toInt(),
        comment: map['comment'] as String? ?? '',
      );
}

class SellerDashboardStats {
  final int totalProducts;
  final int availableProducts;
  final int pendingOrders;
  final int completedOrders;
  final int totalRevenueCentavos;
  final int toShip;
  final int activeReturns;
  final int unreadChats;
  final int lowStock;
  final double averageRating;
  final int totalReviews;
  final List<SellerSalesPoint> salesPoints;
  final List<SellerTopProduct> topProducts;
  final List<SellerRecentReview> recentReviews;

  const SellerDashboardStats({
    required this.totalProducts,
    required this.availableProducts,
    required this.pendingOrders,
    required this.completedOrders,
    required this.totalRevenueCentavos,
    required this.toShip,
    required this.activeReturns,
    required this.unreadChats,
    required this.lowStock,
    required this.averageRating,
    required this.totalReviews,
    required this.salesPoints,
    required this.topProducts,
    required this.recentReviews,
  });

  factory SellerDashboardStats.fromMap(Map<String, dynamic> map) {
    final rawPoints = (map['sales_points'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return SellerDashboardStats(
      totalProducts: (map['total_products'] as num? ?? 0).toInt(),
      availableProducts: (map['available_products'] as num? ?? 0).toInt(),
      pendingOrders: (map['pending_orders'] as num? ?? 0).toInt(),
      completedOrders: (map['completed_orders'] as num? ?? 0).toInt(),
      totalRevenueCentavos: centavosFromDatabase(map['total_revenue']),
      toShip: (map['to_ship'] as num? ?? 0).toInt(),
      activeReturns: (map['active_returns'] as num? ?? 0).toInt(),
      unreadChats: (map['unread_chats'] as num? ?? 0).toInt(),
      lowStock: (map['low_stock'] as num? ?? 0).toInt(),
      averageRating: (map['average_rating'] as num? ?? 0).toDouble(),
      totalReviews: (map['total_reviews'] as num? ?? 0).toInt(),
      salesPoints: [
        for (final point in rawPoints)
          SellerSalesPoint(
            label: _dayLabel(point['day']?.toString() ?? ''),
            revenueCentavos: centavosFromDatabase(point['revenue']),
            orderCount: (point['orders'] as num? ?? 0).toInt(),
          ),
      ],
      topProducts: (map['top_products'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SellerTopProduct.fromMap)
          .toList(),
      recentReviews: (map['recent_reviews'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SellerRecentReview.fromMap)
          .toList(),
    );
  }

  static String _dayLabel(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    return '${date.day}';
  }
}
