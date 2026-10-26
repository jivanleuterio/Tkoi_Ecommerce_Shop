import 'seller_wallet.dart';

class AdminOrderSummary {
  final String id;
  final String status;
  final int totalCentavos;
  final String paymentMethod;
  final String paymentStatus;
  final String buyerName;
  final String shopName;
  final int itemCount;
  final DateTime createdAt;

  const AdminOrderSummary({
    required this.id,
    required this.status,
    required this.totalCentavos,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.buyerName,
    required this.shopName,
    required this.itemCount,
    required this.createdAt,
  });

  factory AdminOrderSummary.fromMap(Map<String, dynamic> map) =>
      AdminOrderSummary(
        id: map['id'] as String,
        status: map['status'] as String? ?? 'pending',
        totalCentavos: centavosFromDatabase(map['total']),
        paymentMethod: map['payment_method'] as String? ?? '',
        paymentStatus: map['payment_status'] as String? ?? '',
        buyerName: map['buyer_name'] as String? ?? 'Tkoi buyer',
        shopName: map['shop_name'] as String? ?? 'Tkoi shop',
        itemCount: (map['item_count'] as num? ?? 0).toInt(),
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AdminReturnRequest {
  final String id;
  final String orderId;
  final String status;
  final String reason;
  final String details;
  final String adminNote;
  final String buyerName;
  final String shopName;
  final int orderTotalCentavos;
  final String paymentMethod;
  final DateTime createdAt;

  const AdminReturnRequest({
    required this.id,
    required this.orderId,
    required this.status,
    required this.reason,
    required this.details,
    required this.adminNote,
    required this.buyerName,
    required this.shopName,
    required this.orderTotalCentavos,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory AdminReturnRequest.fromMap(Map<String, dynamic> map) =>
      AdminReturnRequest(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        status: map['status'] as String? ?? 'requested',
        reason: map['reason'] as String? ?? 'Other',
        details: map['details'] as String? ?? '',
        adminNote: map['admin_note'] as String? ?? '',
        buyerName: map['buyer_name'] as String? ?? 'Tkoi buyer',
        shopName: map['shop_name'] as String? ?? 'Tkoi shop',
        orderTotalCentavos: centavosFromDatabase(map['order_total']),
        paymentMethod: map['payment_method'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AdminWithdrawal {
  final String id;
  final String shopId;
  final String shopName;
  final String sellerName;
  final int amountCentavos;
  final String payoutMethod;
  final String maskedAccount;
  final String status;
  final String adminNote;
  final String? externalReference;
  final bool isDemo;
  final DateTime requestedAt;

  const AdminWithdrawal({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.sellerName,
    required this.amountCentavos,
    required this.payoutMethod,
    required this.maskedAccount,
    required this.status,
    required this.adminNote,
    this.externalReference,
    required this.isDemo,
    required this.requestedAt,
  });

  factory AdminWithdrawal.fromMap(Map<String, dynamic> map) => AdminWithdrawal(
    id: map['id'] as String,
    shopId: map['shop_id'] as String,
    shopName: map['shop_name'] as String? ?? 'Tkoi shop',
    sellerName: map['seller_name'] as String? ?? 'Tkoi seller',
    amountCentavos: centavosFromDatabase(map['amount']),
    payoutMethod: map['payout_method'] as String? ?? '',
    maskedAccount: map['masked_account'] as String? ?? '••••',
    status: map['status'] as String? ?? 'pending',
    adminNote: map['admin_note'] as String? ?? '',
    externalReference: map['external_reference'] as String?,
    isDemo: map['is_demo'] as bool? ?? false,
    requestedAt:
        DateTime.tryParse(map['requested_at'] as String? ?? '') ??
        DateTime.now(),
  );
}

class AdminWalletSummary {
  final String shopId;
  final String shopName;
  final String sellerName;
  final int availableCentavos;
  final int pendingCentavos;
  final int totalEarnedCentavos;
  final int totalWithdrawnCentavos;

  const AdminWalletSummary({
    required this.shopId,
    required this.shopName,
    required this.sellerName,
    required this.availableCentavos,
    required this.pendingCentavos,
    required this.totalEarnedCentavos,
    required this.totalWithdrawnCentavos,
  });

  factory AdminWalletSummary.fromMap(Map<String, dynamic> map) =>
      AdminWalletSummary(
        shopId: map['shop_id'] as String,
        shopName: map['shop_name'] as String? ?? 'Tkoi shop',
        sellerName: map['seller_name'] as String? ?? 'Tkoi seller',
        availableCentavos: centavosFromDatabase(map['available_balance']),
        pendingCentavos: centavosFromDatabase(map['pending_balance']),
        totalEarnedCentavos: centavosFromDatabase(map['total_earned']),
        totalWithdrawnCentavos: centavosFromDatabase(map['total_withdrawn']),
      );
}

class AdminMarketplaceSettings {
  final String platformFeePercent;
  final String minimumWithdrawal;
  final int autoReleaseDays;
  final bool demoMode;

  const AdminMarketplaceSettings({
    required this.platformFeePercent,
    required this.minimumWithdrawal,
    required this.autoReleaseDays,
    required this.demoMode,
  });

  factory AdminMarketplaceSettings.fromMap(Map<String, dynamic> map) =>
      AdminMarketplaceSettings(
        platformFeePercent: map['platform_fee_percent']?.toString() ?? '5.00',
        minimumWithdrawal: map['minimum_withdrawal']?.toString() ?? '100.00',
        autoReleaseDays: (map['auto_release_days'] as num? ?? 7).toInt(),
        demoMode: map['demo_mode'] as bool? ?? true,
      );
}

class AdminAuditEntry {
  final String id;
  final String adminName;
  final String action;
  final String targetType;
  final String? targetId;
  final String reason;
  final DateTime createdAt;

  const AdminAuditEntry({
    required this.id,
    required this.adminName,
    required this.action,
    required this.targetType,
    this.targetId,
    required this.reason,
    required this.createdAt,
  });

  factory AdminAuditEntry.fromMap(Map<String, dynamic> map) => AdminAuditEntry(
    id: map['id'] as String,
    adminName: map['admin_name'] as String? ?? 'Tkoi admin',
    action: map['action'] as String? ?? '',
    targetType: map['target_type'] as String? ?? '',
    targetId: map['target_id'] as String?,
    reason: map['reason'] as String? ?? '',
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}
