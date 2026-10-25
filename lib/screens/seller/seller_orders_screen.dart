import 'package:flutter/material.dart';

import '../../models/market_order.dart';
import '../../models/shop.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import 'seller_order_details_screen.dart';

class SellerOrdersScreen extends StatefulWidget {
  final Shop shop;

  const SellerOrdersScreen({super.key, required this.shop});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  static const filters = [
    'All',
    'Pending',
    'To ship',
    'Shipping',
    'Completed',
    'Cancelled',
    'Return / Refund',
  ];
  static const statuses = [
    'pending',
    'confirmed',
    'preparing',
    'ready_for_delivery',
    'shipped',
    'completed',
    'cancelled',
  ];

  late Future<List<MarketOrder>> _future;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = OrderService().getSellerOrders(widget.shop.id);
  }

  void _refresh() => setState(_load);

  List<MarketOrder> _filtered(List<MarketOrder> orders) => switch (_filter) {
    'Pending' => orders.where((order) => order.status == 'pending').toList(),
    'To ship' =>
      orders
          .where(
            (order) => const {
              'confirmed',
              'preparing',
              'ready_for_delivery',
            }.contains(order.status),
          )
          .toList(),
    'Shipping' => orders.where((order) => order.status == 'shipped').toList(),
    'Completed' =>
      orders.where((order) => order.status == 'completed').toList(),
    'Cancelled' =>
      orders.where((order) => order.status == 'cancelled').toList(),
    'Return / Refund' =>
      orders.where((order) => order.returnRequest != null).toList(),
    _ => orders,
  };

  Future<void> _update(String orderId, String status) async {
    try {
      await OrderService().updateStatus(orderId, status);
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _updateReturn(String returnId, String status) async {
    try {
      await OrderService().updateReturnStatus(returnId, status);
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  List<String> _nextReturnStatuses(String status) => switch (status) {
    'requested' => const ['approved', 'rejected'],
    'approved' => const ['received'],
    'received' => const ['resolved'],
    _ => const [],
  };

  String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.shop.name} orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final value = filters[index];
                return ChoiceChip(
                  label: Text(value),
                  selected: value == _filter,
                  onSelected: (_) => setState(() => _filter = value),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MarketOrder>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const TkoiLoadingView(
                    message: 'Loading shop orders...',
                  );
                }
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error!, onRetry: _refresh);
                }
                final allOrders = snapshot.data ?? const <MarketOrder>[];
                final orders = _filtered(allOrders);
                if (orders.isEmpty) {
                  return EmptyState(
                    icon: Icons.inbox_outlined,
                    title: _filter == 'All'
                        ? 'No received orders'
                        : 'No ${_filter.toLowerCase()} orders',
                    message: _filter == 'All'
                        ? 'Orders containing your fish will appear here.'
                        : 'Orders will appear here when they match this status.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _OrderCard(
                      order: orders[index],
                      statuses: statuses,
                      nextReturnStatuses: _nextReturnStatuses,
                      dateLabel: _date,
                      onStatusChanged: _update,
                      onReturnChanged: _updateReturn,
                      onOpen: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SellerOrderDetailsScreen(order: orders[index]),
                          ),
                        );
                        if (changed == true) _refresh();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final MarketOrder order;
  final List<String> statuses;
  final List<String> Function(String) nextReturnStatuses;
  final String Function(DateTime) dateLabel;
  final Future<void> Function(String, String) onStatusChanged;
  final Future<void> Function(String, String) onReturnChanged;
  final VoidCallback onOpen;

  const _OrderCard({
    required this.order,
    required this.statuses,
    required this.nextReturnStatuses,
    required this.dateLabel,
    required this.onStatusChanged,
    required this.onReturnChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final waitingForPayment =
        order.paymentMethod == 'Xendit' && order.paymentStatus != 'paid';
    final availableStatuses = order.status == 'completed'
        ? const ['completed']
        : statuses.where((status) => status != 'completed').where((status) {
            return !(order.paymentMethod == 'Xendit' &&
                order.paymentStatus == 'paid' &&
                status == 'cancelled');
          }).toList();
    final returnRequest = order.returnRequest;
    final returnStatuses = returnRequest == null
        ? const <String>[]
        : nextReturnStatuses(returnRequest.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.buyerName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Order ${order.id.substring(0, 8).toUpperCase()} • ${dateLabel(order.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const Divider(height: 22),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item.quantity}× ${item.productName} — ${peso(item.unitPrice)}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(order.paymentLabel),
                  const Spacer(),
                  Text(
                    peso(order.total),
                    style: const TextStyle(
                      color: AppColors.koiOrange,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (returnRequest != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.pondBlue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return ${returnRequest.status.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          color: AppColors.pondBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(returnRequest.reason),
                      if (returnStatuses.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Update return request',
                          ),
                          items: returnStatuses
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status.replaceAll('_', ' ')),
                                ),
                              )
                              .toList(),
                          onChanged: (status) {
                            if (status != null) {
                              onReturnChanged(returnRequest.id, status);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (waitingForPayment)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Waiting for Xendit payment confirmation.',
                    style: TextStyle(
                      color: AppColors.vermilion,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: order.status,
                decoration: const InputDecoration(labelText: 'Order status'),
                items: availableStatuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged:
                    waitingForPayment ||
                        order.status == 'cancelled' ||
                        order.status == 'completed'
                    ? null
                    : (status) {
                        if (status != null) onStatusChanged(order.id, status);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
