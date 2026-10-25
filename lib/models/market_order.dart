import 'seller_wallet.dart';

class OrderLine {
  final String id;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? imageUrl;
  final bool reviewed;

  const OrderLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
    this.reviewed = false,
  });

  OrderLine copyWith({bool? reviewed}) => OrderLine(
    id: id,
    productId: productId,
    productName: productName,
    quantity: quantity,
    unitPrice: unitPrice,
    imageUrl: imageUrl,
    reviewed: reviewed ?? this.reviewed,
  );

  factory OrderLine.fromMap(Map<String, dynamic> map) => OrderLine(
    id: map['id'] as String? ?? '',
    productId: map['product_id'] as String?,
    productName: map['product_name'] as String? ?? 'Fish',
    quantity: (map['quantity'] as num? ?? 1).toInt(),
    unitPrice: (map['unit_price'] as num? ?? 0).toDouble(),
    imageUrl: map['image_url'] as String?,
  );
}

class OrderReview {
  final String id;
  final int rating;
  final String comment;
  final DateTime createdAt;

  const OrderReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory OrderReview.fromMap(Map<String, dynamic> map) => OrderReview(
    id: map['id'] as String,
    rating: (map['rating'] as num? ?? 0).toInt(),
    comment: map['comment'] as String? ?? '',
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class OrderReturnRequest {
  final String id;
  final String status;
  final String reason;
  final String details;
  final DateTime createdAt;

  const OrderReturnRequest({
    required this.id,
    required this.status,
    required this.reason,
    required this.details,
    required this.createdAt,
  });

  factory OrderReturnRequest.fromMap(Map<String, dynamic> map) =>
      OrderReturnRequest(
        id: map['id'] as String,
        status: map['status'] as String? ?? 'requested',
        reason: map['reason'] as String? ?? 'Other',
        details: map['details'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class MarketOrder {
  final String id;
  final String buyerId;
  final String sellerId;
  final String shopId;
  final String shopName;
  final String buyerName;
  final String? buyerAvatarUrl;
  final String status;
  final double total;
  final String deliveryAddress;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentChannel;
  final String? paymentTransactionId;
  final int platformFeeCentavos;
  final int netEarningsCentavos;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<OrderLine> items;
  final OrderReview? review;
  final OrderReturnRequest? returnRequest;

  const MarketOrder({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.shopId,
    required this.shopName,
    this.buyerName = 'Buyer',
    this.buyerAvatarUrl,
    required this.status,
    required this.total,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paymentChannel,
    this.paymentTransactionId,
    this.platformFeeCentavos = 0,
    this.netEarningsCentavos = 0,
    required this.createdAt,
    this.completedAt,
    required this.items,
    this.review,
    this.returnRequest,
  });

  MarketOrder copyWith({
    OrderReview? review,
    OrderReturnRequest? returnRequest,
    List<OrderLine>? items,
    String? buyerName,
    String? buyerAvatarUrl,
  }) => MarketOrder(
    id: id,
    buyerId: buyerId,
    sellerId: sellerId,
    shopId: shopId,
    shopName: shopName,
    buyerName: buyerName ?? this.buyerName,
    buyerAvatarUrl: buyerAvatarUrl ?? this.buyerAvatarUrl,
    status: status,
    total: total,
    deliveryAddress: deliveryAddress,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    paymentChannel: paymentChannel,
    paymentTransactionId: paymentTransactionId,
    platformFeeCentavos: platformFeeCentavos,
    netEarningsCentavos: netEarningsCentavos,
    createdAt: createdAt,
    completedAt: completedAt,
    items: items ?? this.items,
    review: review ?? this.review,
    returnRequest: returnRequest ?? this.returnRequest,
  );

  factory MarketOrder.fromMap(Map<String, dynamic> map) {
    final shop = map['shops'] as Map<String, dynamic>?;
    return MarketOrder(
      id: map['id'] as String,
      buyerId: map['buyer_id'] as String,
      sellerId: map['seller_id'] as String,
      shopId: map['shop_id'] as String,
      shopName:
          map['shop_name'] as String? ??
          shop?['name'] as String? ??
          'Fish Shop',
      buyerName: map['buyer_name'] as String? ?? 'Buyer',
      buyerAvatarUrl: map['buyer_avatar_url'] as String?,
      status: map['status'] as String? ?? 'pending',
      total: (map['total'] as num? ?? 0).toDouble(),
      deliveryAddress: map['delivery_address'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? 'Cash on Delivery',
      paymentStatus: map['payment_status'] as String? ?? 'not_required',
      paymentChannel: map['payment_channel'] as String?,
      paymentTransactionId: map['payment_transaction_id'] as String?,
      platformFeeCentavos: centavosFromDatabase(map['platform_fee']),
      netEarningsCentavos: centavosFromDatabase(map['net_earnings']),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      completedAt:
          DateTime.tryParse(map['completed_at'] as String? ?? '') ??
          (map['status'] == 'completed'
              ? DateTime.tryParse(map['updated_at'] as String? ?? '')
              : null),
      items: (map['order_items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OrderLine.fromMap)
          .toList(),
    );
  }

  String get paymentLabel => switch (paymentChannel) {
    'GCASH' => 'GCash',
    'PAYMAYA' => 'Maya',
    'CARDS' => 'Credit or debit card',
    'BPI_ONLINE_BANKING' => 'BPI Online Banking',
    'BDO_ONLINE_BANKING' => 'BDO Online Banking',
    'UNIONBANK_ONLINE_BANKING' => 'UnionBank Online Banking',
    'QRPH' => 'QRPh',
    'ONLINE' => 'Online payment',
    _ => paymentMethod,
  };

  DateTime? get returnDeadline => completedAt?.add(const Duration(days: 1));

  bool get isReturnWindowOpen {
    final deadline = returnDeadline;
    return status == 'completed' &&
        deadline != null &&
        DateTime.now().isBefore(deadline);
  }
}
