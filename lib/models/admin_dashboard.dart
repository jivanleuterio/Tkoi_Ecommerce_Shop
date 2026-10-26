import 'seller_wallet.dart';

class AdminSalesPoint {
  final DateTime day;
  final int orders;
  final int revenueCentavos;

  const AdminSalesPoint({
    required this.day,
    required this.orders,
    required this.revenueCentavos,
  });

  factory AdminSalesPoint.fromMap(Map<String, dynamic> map) => AdminSalesPoint(
    day: DateTime.tryParse(map['day']?.toString() ?? '') ?? DateTime.now(),
    orders: (map['orders'] as num? ?? 0).toInt(),
    revenueCentavos: centavosFromDatabase(map['revenue']),
  );
}

class AdminDashboardStats {
  final Map<String, int> counts;
  final int revenue7dCentavos;
  final int revenue30dCentavos;
  final List<AdminSalesPoint> salesPoints;

  const AdminDashboardStats({
    required this.counts,
    required this.revenue7dCentavos,
    required this.revenue30dCentavos,
    required this.salesPoints,
  });

  factory AdminDashboardStats.fromMap(Map<String, dynamic> map) =>
      AdminDashboardStats(
        counts: {
          for (final key in [
            'total_users',
            'new_users_7d',
            'total_shops',
            'active_listings',
            'orders_7d',
            'orders_30d',
            'open_tickets',
            'open_reports',
            'pending_returns',
            'pending_withdrawals',
            'suspended_users',
            'banned_users',
            'negative_balance_shops',
          ])
            key: (map[key] as num? ?? 0).toInt(),
        },
        revenue7dCentavos: centavosFromDatabase(map['revenue_7d']),
        revenue30dCentavos: centavosFromDatabase(map['revenue_30d']),
        salesPoints: (map['sales_points'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AdminSalesPoint.fromMap)
            .toList(),
      );

  int count(String key) => counts[key] ?? 0;
}
