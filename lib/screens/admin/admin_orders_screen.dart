import 'package:flutter/material.dart';

import '../../models/admin_operations.dart';
import '../../models/seller_wallet.dart';
import '../../services/admin_operations_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _search = TextEditingController();
  String? _status;
  late Future<List<AdminOrderSummary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _future = AdminOperationsService().getOrders(
      status: _status,
      search: _search.text,
    );
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onSubmitted: (_) => _refresh(),
                decoration: const InputDecoration(
                  hintText: 'Order, buyer, or shop',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            PopupMenuButton<String?>(
              tooltip: 'Filter order status',
              onSelected: (value) {
                _status = value;
                _refresh();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: null, child: Text('All statuses')),
                PopupMenuItem(value: 'pending', child: Text('Pending')),
                PopupMenuItem(value: 'shipped', child: Text('Shipped')),
                PopupMenuItem(value: 'completed', child: Text('Completed')),
                PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              icon: const Icon(Icons.filter_list),
            ),
            Text(_status ?? 'All'),
            IconButton(
              tooltip: 'Refresh orders',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<AdminOrderSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TkoiLoadingView(message: 'Loading orders...');
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _refresh);
            }
            final orders = snapshot.data ?? const [];
            if (orders.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders found',
                message: 'Try another filter or search.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminOrderDetailScreen(orderId: order.id),
                        ),
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.receipt_long_outlined),
                      ),
                      title: Text(
                        '${order.shopName} | ${pesoCentavos(order.totalCentavos)}',
                      ),
                      subtitle: Text(
                        '${order.buyerName} | ${order.itemCount} items\n${order.paymentMethod} | ${order.paymentStatus}',
                      ),
                      isThreeLine: true,
                      trailing: Chip(label: Text(order.status)),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  String? _address;

  @override
  void initState() {
    super.initState();
    _future = AdminOperationsService().getOrder(widget.orderId);
  }

  Future<void> _reveal() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _AddressRevealDialog(orderId: widget.orderId),
    );
    if (!mounted || reason == null) return;
    try {
      final address = await AdminOperationsService().revealAddress(
        widget.orderId,
        reason,
      );
      if (mounted) {
        setState(() => _address = address);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Shipping address revealed and access audited.'),
            ),
          );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin order details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!);
        }
        final order = snapshot.data!;
        final items = (order['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${(order['id'] as String).substring(0, 8).toUpperCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('${order['shop_name']} | ${order['buyer_name']}'),
                    Text(
                      '${order['status']} | ${order['payment_method']} (${order['payment_status']})',
                    ),
                    Text(
                      peso((order['total'] as num?) ?? 0),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Shipping address'),
                subtitle: Text(
                  _address ?? 'Hidden until an audited reveal is requested.',
                ),
                trailing: _address == null
                    ? TextButton(
                        onPressed: _reveal,
                        child: const Text('Reveal'),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text('Items', style: Theme.of(context).textTheme.titleLarge),
            for (final item in items)
              Card(
                child: ListTile(
                  title: Text(item['product_name'] as String? ?? 'Fish'),
                  subtitle: Text(
                    '${item['quantity']} × ${peso((item['unit_price'] as num?) ?? 0)}',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Provider checkout URLs and Xendit session IDs are intentionally not exposed.',
            ),
          ],
        );
      },
    ),
  );
}

class _AddressRevealDialog extends StatefulWidget {
  final String orderId;

  const _AddressRevealDialog({required this.orderId});

  @override
  State<_AddressRevealDialog> createState() => _AddressRevealDialogState();
}

class _AddressRevealDialogState extends State<_AddressRevealDialog> {
  final _reason = TextEditingController();
  bool _canReveal = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reveal shipping address?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order ${widget.orderId.substring(0, 8).toUpperCase()}\n'
          'This privacy-sensitive access will be recorded in the audit log.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          onChanged: (value) =>
              setState(() => _canReveal = value.trim().length >= 10),
          decoration: const InputDecoration(
            labelText: 'Required audit reason',
            helperText: 'At least 10 characters.',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _canReveal
            ? () => Navigator.pop(context, _reason.text.trim())
            : null,
        child: const Text('Reveal address'),
      ),
    ],
  );
}
