import 'package:flutter/material.dart';

import '../../models/market_order.dart';
import '../../models/seller_wallet.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/safe_network_image.dart';

class SellerOrderDetailsScreen extends StatefulWidget {
  final MarketOrder order;

  const SellerOrderDetailsScreen({super.key, required this.order});

  @override
  State<SellerOrderDetailsScreen> createState() =>
      _SellerOrderDetailsScreenState();
}

class _SellerOrderDetailsScreenState extends State<SellerOrderDetailsScreen> {
  bool _busy = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _busy = true);
    try {
      await OrderService().updateStatus(widget.order.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order moved to ${_label(status)}.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> get _allowedNext => switch (widget.order.status) {
    'pending' => const ['confirmed', 'cancelled'],
    'confirmed' => const ['preparing', 'cancelled'],
    'preparing' => const ['ready_for_delivery', 'cancelled'],
    'ready_for_delivery' => const ['shipped', 'cancelled'],
    _ => const [],
  };

  String _label(String value) => value
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

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
    final order = widget.order;
    final unpaidOnline =
        order.paymentMethod == 'Xendit' && order.paymentStatus != 'paid';
    final nextStatuses = _allowedNext.where((status) {
      return !(order.paymentMethod == 'Xendit' &&
          order.paymentStatus == 'paid' &&
          status == 'cancelled');
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order ${order.id.substring(0, 8).toUpperCase()}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Chip(label: Text(_label(order.status))),
                    ],
                  ),
                  Text('Placed ${_date(order.createdAt)}'),
                  const Divider(height: 26),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.aqua.withValues(alpha: .14),
                      child: const Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(order.buyerName),
                    subtitle: const Text('Buyer'),
                  ),
                  if (order.paymentMethod == 'Xendit' &&
                      order.netEarningsCentavos > 0) ...[
                    const SizedBox(height: 8),
                    _MoneyRow(label: 'Gross', value: peso(order.total)),
                    _MoneyRow(
                      label: 'Platform fee',
                      value: '-${pesoCentavos(order.platformFeeCentavos)}',
                    ),
                    _MoneyRow(
                      label: 'Net earnings',
                      value: pesoCentavos(order.netEarningsCentavos),
                      strong: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final item in order.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SafeNetworkImage(
                        url: item.imageUrl,
                        width: 54,
                        height: 54,
                      ),
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.quantity} × ${peso(item.unitPrice)}',
                      ),
                      trailing: Text(
                        peso(item.unitPrice * item.quantity),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Order total'),
                      const Spacer(),
                      Text(
                        peso(order.total),
                        style: const TextStyle(
                          color: AppColors.koiOrange,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment & delivery',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Payment: ${order.paymentLabel}'),
                  if (order.paymentMethod == 'Xendit')
                    Text('Payment status: ${_label(order.paymentStatus)}'),
                  const SizedBox(height: 10),
                  Text('Deliver to: ${order.deliveryAddress}'),
                ],
              ),
            ),
          ),
          if (order.returnRequest case final request?) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.cream,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Return / refund: ${_label(request.status)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(request.reason),
                    if (request.details.isNotEmpty) Text(request.details),
                  ],
                ),
              ),
            ),
          ],
          if (unpaidOnline) ...[
            const SizedBox(height: 12),
            const Text(
              'Wait for Xendit to confirm payment before processing this order.',
              style: TextStyle(
                color: AppColors.vermilion,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (nextStatuses.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Next action', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in nextStatuses)
                  status == 'cancelled'
                      ? OutlinedButton(
                          onPressed: _busy || unpaidOnline
                              ? null
                              : () => _updateStatus(status),
                          child: const Text('Cancel order'),
                        )
                      : FilledButton(
                          onPressed: _busy || unpaidOnline
                              ? null
                              : () => _updateStatus(status),
                          child: Text(_label(status)),
                        ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _MoneyRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontWeight: strong ? FontWeight.w900 : null),
        ),
      ],
    ),
  );
}
