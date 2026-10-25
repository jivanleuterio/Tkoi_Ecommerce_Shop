import 'package:flutter/material.dart';

import '../../models/market_order.dart';
import '../../models/shop.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

class SellerOrdersScreen extends StatefulWidget {
  final Shop shop;

  const SellerOrdersScreen({super.key, required this.shop});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = OrderService().getSellerOrders(widget.shop.id);
  }

  void _refresh() {
    setState(() {
      _load();
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.shop.name} orders')),
      body: FutureBuilder<List<MarketOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Loading shop orders...');
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _refresh);
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No received orders',
              message: 'Orders containing your fish will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final order = orders[index];
              final waitingForPayment =
                  order.paymentMethod == 'Xendit' &&
                  order.paymentStatus != 'paid';
              final availableStatuses = order.status == 'completed'
                  ? const ['completed']
                  : statuses.where((status) => status != 'completed').where((
                      status,
                    ) {
                      return !(order.paymentMethod == 'Xendit' &&
                          order.paymentStatus == 'paid' &&
                          status == 'cancelled');
                    }).toList();
              final returnRequest = order.returnRequest;
              final nextReturnStatuses = returnRequest == null
                  ? const <String>[]
                  : _nextReturnStatuses(returnRequest.status);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ${order.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(
                          color: AppColors.pondBlue,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...order.items.map(
                        (item) => Text(
                          '${item.quantity}× ${item.productName} — ${peso(item.unitPrice)}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Order total'),
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
                      Text('Payment: ${order.paymentLabel}'),
                      if (order.paymentMethod == 'Xendit')
                        Text(
                          'Payment status: ${order.paymentStatus.replaceAll('_', ' ')}',
                        ),
                      Text('Delivery: ${order.deliveryAddress}'),
                      if (returnRequest != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.pondBlue.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
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
                              Text(returnRequest.details),
                              if (nextReturnStatuses.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Update return request',
                                  ),
                                  items: nextReturnStatuses
                                      .map(
                                        (status) => DropdownMenuItem(
                                          value: status,
                                          child: Text(
                                            status.replaceAll('_', ' '),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (status) {
                                    if (status != null) {
                                      _updateReturn(returnRequest.id, status);
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
                            'Wait for Xendit to confirm payment before processing this order.',
                            style: TextStyle(
                              color: AppColors.vermilion,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: order.status,
                        decoration: const InputDecoration(
                          labelText: 'Order status',
                        ),
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
                                if (status != null) _update(order.id, status);
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
