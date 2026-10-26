import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../models/admin_dashboard.dart';
import '../../models/seller_wallet.dart';
import '../../services/admin_dashboard_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import 'admin_finance_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_tickets_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AdminAccessContext access;
  const AdminDashboardScreen({super.key, required this.access});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminDashboardStats> _future;
  @override
  void initState() {
    super.initState();
    _future = AdminDashboardService().getStats();
  }

  void _refresh() =>
      setState(() => _future = AdminDashboardService().getStats());

  void _open(Widget screen, String title) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: screen,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminDashboardStats>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const TkoiLoadingView(message: 'Loading admin dashboard...');
      }
      if (snapshot.hasError) {
        return ErrorView(error: snapshot.error!, onRetry: _refresh);
      }
      final stats = snapshot.data!;
      final canUsers =
          widget.access.hasPermission('users.view') ||
          widget.access.hasPermission('users.suspend');
      final canContent = widget.access.hasPermission('content.moderate');
      final canOrders = widget.access.hasPermission('orders.view');
      final canTickets = widget.access.hasPermission('tickets.view');
      final canReports = widget.access.hasPermission('reports.view');
      final canReturns = widget.access.hasPermission('returns.decide');
      final canWithdrawals = widget.access.hasPermission('withdrawals.view');
      final canWallet = widget.access.hasPermission('wallet.view');
      final cards = <Widget>[
        if (canUsers)
          _MetricCard(
            label: 'Users',
            value: '${stats.count('total_users')}',
            detail: '+${stats.count('new_users_7d')} this week',
            icon: Icons.people_outline,
            onTap: () => _open(const AdminUsersScreen(), 'Users'),
          ),
        if (canContent)
          _MetricCard(
            label: 'Shops',
            value: '${stats.count('total_shops')}',
            detail: '${stats.count('active_listings')} active listings',
            icon: Icons.storefront_outlined,
          ),
        if (canOrders)
          _MetricCard(
            label: '7-day orders',
            value: '${stats.count('orders_7d')}',
            detail: pesoCentavos(stats.revenue7dCentavos),
            icon: Icons.receipt_long_outlined,
            onTap: () => _open(const AdminOrdersScreen(), 'Orders'),
          ),
        if (canOrders)
          _MetricCard(
            label: '30-day revenue',
            value: pesoCentavos(stats.revenue30dCentavos),
            detail: '${stats.count('orders_30d')} orders',
            icon: Icons.trending_up,
          ),
        if (canTickets)
          _MetricCard(
            label: 'Open tickets',
            value: '${stats.count('open_tickets')}',
            detail: 'Needs support',
            icon: Icons.support_agent,
            onTap: () =>
                _open(AdminTicketsScreen(access: widget.access), 'Support'),
          ),
        if (canReports)
          _MetricCard(
            label: 'Open reports',
            value: '${stats.count('open_reports')}',
            detail: 'Needs moderation',
            icon: Icons.flag_outlined,
            onTap: () =>
                _open(AdminReportsScreen(access: widget.access), 'Reports'),
          ),
        if (widget.access.hasPermission('users.suspend'))
          _MetricCard(
            label: 'Restricted',
            value:
                '${stats.count('suspended_users') + stats.count('banned_users')}',
            detail:
                '${stats.count('suspended_users')} suspended | ${stats.count('banned_users')} banned',
            icon: Icons.block_outlined,
          ),
        if (canReturns || canWithdrawals || canWallet)
          _MetricCard(
            label: 'Finance queue',
            value:
                '${(canReturns ? stats.count('pending_returns') : 0) + (canWithdrawals ? stats.count('pending_withdrawals') : 0)}',
            detail: canWallet
                ? '${stats.count('negative_balance_shops')} negative wallets'
                : 'Needs review',
            icon: Icons.payments_outlined,
            onTap: canWallet
                ? () => _open(
                    AdminFinanceScreen(access: widget.access),
                    'Finance',
                  )
                : null,
          ),
      ];
      return RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            Text(
              'Marketplace overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.42,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: cards,
            ),
            if (canOrders) ...[
              const SizedBox(height: 18),
              Text(
                'Orders and revenue | 30 days',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    height: 190,
                    child: _AdminSalesChart(points: stats.salesPoints),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback? onTap;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.pondBlue),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.softGray),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AdminSalesChart extends StatelessWidget {
  final List<AdminSalesPoint> points;
  const _AdminSalesChart({required this.points});
  @override
  Widget build(BuildContext context) {
    final maxRevenue = points.fold<int>(
      1,
      (value, point) => math.max(value, point.revenueCentavos),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < points.length; index++)
          Expanded(
            child: Tooltip(
              message:
                  '${points[index].orders} orders | ${pesoCentavos(points[index].revenueCentavos)}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: math.max(
                        2,
                        145 * points[index].revenueCentavos / maxRevenue,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.waterGradient,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (index % 5 == 0 || index == points.length - 1)
                      Text(
                        '${points[index].day.day}',
                        style: const TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
