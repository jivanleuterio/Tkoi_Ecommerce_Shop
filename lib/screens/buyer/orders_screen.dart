import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/market_order.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_visuals.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/cart_action.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';
import 'order_details_screen.dart';
import 'review_composer_screen.dart';

enum _OrderView { all, toPay, toShip, toReceive, toReview, returns }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  static const _views = _OrderView.values;
  static const _returnReasons = [
    'Fish arrived unhealthy',
    'Wrong fish received',
    'Item damaged in transit',
    'Order incomplete',
    'Other',
  ];

  late final TabController _tabs;
  late Future<List<MarketOrder>> _future;
  String? _busyOrderId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _views.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _load() {
    _future = OrderService().getMyOrders();
  }

  Future<void> _refresh() async {
    setState(() {
      _load();
    });
    await _future;
  }

  bool _needsPayment(MarketOrder order) =>
      order.paymentMethod == 'Xendit' &&
      order.status == 'pending' &&
      !const [
        'paid',
        'expired',
        'failed',
        'cancelled',
      ].contains(order.paymentStatus);

  bool _canReview(MarketOrder order) {
    final returnStatus = order.returnRequest?.status;
    return order.status == 'completed' &&
        order.review == null &&
        (returnStatus == null ||
            const [
              'rejected',
              'cancelled',
              'resolved',
            ].contains(returnStatus)) &&
        order.items.any(
          (item) =>
              item.id.isNotEmpty && item.productId != null && !item.reviewed,
        );
  }

  bool _isInView(MarketOrder order, _OrderView view) => switch (view) {
    _OrderView.all => true,
    _OrderView.toPay => _needsPayment(order),
    _OrderView.toShip =>
      !_needsPayment(order) &&
          const [
            'pending',
            'confirmed',
            'preparing',
            'ready_for_delivery',
          ].contains(order.status),
    _OrderView.toReceive => order.status == 'shipped',
    _OrderView.toReview => _canReview(order),
    _OrderView.returns =>
      order.returnRequest != null ||
          order.status == 'cancelled' ||
          const [
            'expired',
            'failed',
            'cancelled',
          ].contains(order.paymentStatus),
  };

  String _viewLabel(_OrderView view) => switch (view) {
    _OrderView.all => 'All',
    _OrderView.toPay => 'To pay',
    _OrderView.toShip => 'To ship',
    _OrderView.toReceive => 'To receive',
    _OrderView.toReview => 'To review',
    _OrderView.returns => 'Returns',
  };

  IconData _emptyIcon(_OrderView view) => switch (view) {
    _OrderView.toPay => Icons.account_balance_wallet_outlined,
    _OrderView.toShip => Icons.inventory_2_outlined,
    _OrderView.toReceive => Icons.local_shipping_outlined,
    _OrderView.toReview => Icons.rate_review_outlined,
    _OrderView.returns => Icons.assignment_return_outlined,
    _ => Icons.receipt_long_outlined,
  };

  Future<void> _runAction(
    MarketOrder order,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    setState(() => _busyOrderId = order.id);
    try {
      await action();
      await _refresh();
      if (mounted && successMessage != null) _showMessage(successMessage);
    } catch (error) {
      if (mounted) _showMessage(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  Future<void> _cancel(MarketOrder order) async {
    var linkedOrders = 1;
    if (order.paymentMethod == 'Xendit' && order.paymentTransactionId != null) {
      try {
        final currentOrders = await OrderService().getMyOrders();
        linkedOrders = currentOrders
            .where(
              (candidate) =>
                  candidate.status == 'pending' &&
                  candidate.paymentTransactionId == order.paymentTransactionId,
            )
            .length;
        if (linkedOrders < 1) linkedOrders = 1;
      } catch (_) {
        // Cancellation itself still performs authoritative server checks.
      }
    }
    final itemCount = order.items.length;
    final isOnline = order.paymentMethod == 'Xendit';
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isOnline ? 'Cancel this payment?' : 'Cancel this order?'),
        content: Text(
          isOnline && linkedOrders > 1
              ? 'This payment covers $linkedOrders linked orders. Cancelling it will cancel all of them and return all reserved stock to their sellers.'
              : itemCount > 1
              ? 'This order contains $itemCount fish listings. Cancelling it will cancel every item in this order and return their reserved stock.'
              : 'The reserved stock will be returned to the seller.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isOnline && linkedOrders > 1
                  ? 'Cancel all $linkedOrders orders'
                  : isOnline
                  ? 'Cancel payment'
                  : 'Cancel order',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      order,
      () async {
        if (isOnline) {
          final transactionId = order.paymentTransactionId;
          if (transactionId == null) {
            throw Exception('This payment has no transaction reference.');
          }
          await PaymentService().cancel(transactionId);
        } else {
          await OrderService().cancelOrder(order.id);
        }
      },
      successMessage: isOnline && linkedOrders > 1
          ? '$linkedOrders linked orders were cancelled and their stock was restored.'
          : 'Order cancelled and reserved stock restored.',
    );
  }

  Future<void> _openPayment(MarketOrder order) async {
    final transactionId = order.paymentTransactionId;
    if (transactionId == null) {
      _showMessage('This payment has no transaction reference.');
      return;
    }
    try {
      final checkoutUrl = await PaymentService().getCheckoutUrl(transactionId);
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('The secure payment link is no longer available.');
      }
      final opened = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Could not open the secure payment page.');
    } catch (error) {
      _showMessage(friendlyError(error));
    }
  }

  Future<void> _checkPayment(MarketOrder order) async {
    final transactionId = order.paymentTransactionId;
    if (transactionId == null) {
      _showMessage('This payment has no transaction reference.');
      return;
    }
    await _runAction(order, () async {
      final status = await PaymentService().getStatus(transactionId);
      if (status != 'paid') {
        throw Exception('Payment is still ${status.replaceAll('_', ' ')}.');
      }
      if (mounted) _showMessage('Payment confirmed. Your order is ready.');
    });
  }

  Future<void> _markReceived(MarketOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Did your fish arrive?'),
        content: const Text(
          'Confirm only after you have received and inspected the order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Order received'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(order, () => OrderService().markReceived(order.id));
    }
  }

  Future<void> _review(MarketOrder order) async {
    final reviewable = order.items
        .where(
          (item) =>
              item.id.isNotEmpty && item.productId != null && !item.reviewed,
        )
        .toList();
    if (reviewable.isEmpty) return;
    OrderLine? selected;
    if (reviewable.length == 1) {
      selected = reviewable.single;
    } else {
      selected = await showDialog<OrderLine>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Choose a fish to review'),
          children: [
            for (final item in reviewable)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, item),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text('${item.quantity} purchased'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
          ],
        ),
      );
    }
    if (selected == null || !mounted) return;
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReviewComposerScreen(item: selected!)),
    );
    if (submitted == true) _refresh();
  }

  Future<void> _openDetails(MarketOrder order) => Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)),
  );

  Future<void> _requestReturn(MarketOrder order) async {
    var reason = _returnReasons.first;
    final details = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request a return'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: _returnReasons
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => reason = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: details,
                    maxLength: 1000,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                      hintText: 'Describe the condition of the order.',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 10
                        ? 'Enter at least 10 characters.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      await _runAction(
        order,
        () => OrderService().requestReturn(
          orderId: order.id,
          reason: reason,
          details: details.text,
        ),
      );
      if (mounted) _tabs.animateTo(_OrderView.returns.index);
    }
    details.dispose();
  }

  Future<void> _cancelReturn(MarketOrder order) async {
    final request = order.returnRequest;
    if (request == null) return;
    await _runAction(order, () => OrderService().cancelReturn(request.id));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Color _statusColor(String status) {
    if (status == 'cancelled') return AppColors.vermilion;
    if (status == 'completed') return AppColors.success;
    if (status == 'shipped' || status == 'ready_for_delivery') {
      return AppColors.pondBlue;
    }
    return AppColors.koiOrange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const CartAction(),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final view in _views) Tab(text: _viewLabel(view))],
        ),
      ),
      body: FutureBuilder<List<MarketOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Loading your orders...');
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _refresh);
          }
          final orders = snapshot.data ?? [];
          return TabBarView(
            controller: _tabs,
            children: [
              for (final view in _views)
                _OrderList(
                  orders: orders
                      .where((order) => _isInView(order, view))
                      .toList(),
                  view: view,
                  emptyIcon: _emptyIcon(view),
                  emptyTitle: 'Nothing ${_viewLabel(view).toLowerCase()}',
                  onRefresh: _refresh,
                  busyOrderId: _busyOrderId,
                  statusColor: _statusColor,
                  needsPayment: _needsPayment,
                  canReview: _canReview,
                  onOpenPayment: _openPayment,
                  onCheckPayment: _checkPayment,
                  onCancel: _cancel,
                  onReceived: _markReceived,
                  onReview: _review,
                  onReturn: _requestReturn,
                  onCancelReturn: _cancelReturn,
                  onOpenDetails: _openDetails,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<MarketOrder> orders;
  final _OrderView view;
  final IconData emptyIcon;
  final String emptyTitle;
  final Future<void> Function() onRefresh;
  final String? busyOrderId;
  final Color Function(String) statusColor;
  final bool Function(MarketOrder) needsPayment;
  final bool Function(MarketOrder) canReview;
  final Future<void> Function(MarketOrder) onOpenPayment;
  final Future<void> Function(MarketOrder) onCheckPayment;
  final Future<void> Function(MarketOrder) onCancel;
  final Future<void> Function(MarketOrder) onReceived;
  final Future<void> Function(MarketOrder) onReview;
  final Future<void> Function(MarketOrder) onReturn;
  final Future<void> Function(MarketOrder) onCancelReturn;
  final Future<void> Function(MarketOrder) onOpenDetails;

  const _OrderList({
    required this.orders,
    required this.view,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.onRefresh,
    required this.busyOrderId,
    required this.statusColor,
    required this.needsPayment,
    required this.canReview,
    required this.onOpenPayment,
    required this.onCheckPayment,
    required this.onCancel,
    required this.onReceived,
    required this.onReview,
    required this.onReturn,
    required this.onCancelReturn,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: view == _OrderView.all
            ? 'Your placed orders will appear here.'
            : 'Orders will move here automatically as their status changes.',
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final order = orders[index];
          return _OrderCard(
            order: order,
            busy: busyOrderId == order.id,
            statusColor: statusColor(order.status),
            needsPayment: needsPayment(order),
            canReview: canReview(order),
            onOpenPayment: () => onOpenPayment(order),
            onCheckPayment: () => onCheckPayment(order),
            onCancel: () => onCancel(order),
            onReceived: () => onReceived(order),
            onReview: () => onReview(order),
            onReturn: () => onReturn(order),
            onCancelReturn: () => onCancelReturn(order),
            onOpenDetails: () => onOpenDetails(order),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final MarketOrder order;
  final bool busy;
  final Color statusColor;
  final bool needsPayment;
  final bool canReview;
  final VoidCallback onOpenPayment;
  final VoidCallback onCheckPayment;
  final VoidCallback onCancel;
  final VoidCallback onReceived;
  final VoidCallback onReview;
  final VoidCallback onReturn;
  final VoidCallback onCancelReturn;
  final VoidCallback onOpenDetails;

  const _OrderCard({
    required this.order,
    required this.busy,
    required this.statusColor,
    required this.needsPayment,
    required this.canReview,
    required this.onOpenPayment,
    required this.onCheckPayment,
    required this.onCancel,
    required this.onReceived,
    required this.onReview,
    required this.onReturn,
    required this.onCancelReturn,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final returnRequest = order.returnRequest;
    final closedReturn =
        returnRequest == null ||
        const [
          'rejected',
          'cancelled',
          'resolved',
        ].contains(returnRequest.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(order.status.replaceAll('_', ' ')),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor: statusColor.withValues(alpha: .09),
                    side: BorderSide.none,
                  ),
                ],
              ),
              Text(
                'Order ${order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(color: AppColors.softGray, fontSize: 12),
              ),
              const Divider(),
              ...order.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SafeNetworkImage(
                        url: item.imageUrl,
                        fallbackAsset: FishVisuals.forFish(
                          name: item.productName,
                        ),
                        width: 52,
                        height: 52,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${item.quantity}× ${item.productName}'),
                      ),
                      Text(
                        peso(item.quantity * item.unitPrice),
                        style: const TextStyle(
                          color: AppColors.koiOrange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: AppColors.pondBlue,
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Text(order.paymentLabel)),
                  Text(
                    peso(order.total),
                    style: const TextStyle(
                      color: AppColors.koiOrange,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Deliver to: ${order.deliveryAddress}',
                style: const TextStyle(color: AppColors.softGray),
              ),
              if (order.review case final review?) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => Icon(
                          index < review.rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.gold,
                          size: 20,
                        ),
                      ),
                      if (review.comment.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            review.comment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
                      Text(
                        returnRequest.details,
                        style: const TextStyle(color: AppColors.softGray),
                      ),
                    ],
                  ),
                ),
              ],
              if (busy) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ] else ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (needsPayment) ...[
                      FilledButton.icon(
                        onPressed: onOpenPayment,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Pay now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onCheckPayment,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check payment'),
                      ),
                    ],
                    if (order.status == 'shipped')
                      FilledButton.icon(
                        onPressed: onReceived,
                        icon: const Icon(Icons.inventory_rounded),
                        label: const Text('Order received'),
                      ),
                    if (canReview)
                      FilledButton.icon(
                        onPressed: onReview,
                        icon: const Icon(Icons.star_rounded),
                        label: const Text('Review'),
                      ),
                    if (order.status == 'completed' && closedReturn)
                      OutlinedButton.icon(
                        onPressed: onReturn,
                        icon: const Icon(Icons.assignment_return_outlined),
                        label: Text(
                          returnRequest == null
                              ? 'Request return'
                              : 'Request again',
                        ),
                      ),
                    if (returnRequest?.status == 'requested')
                      TextButton(
                        onPressed: onCancelReturn,
                        child: const Text('Cancel return request'),
                      ),
                    if (order.status == 'pending' &&
                        (order.paymentMethod != 'Xendit' || needsPayment))
                      TextButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: Text(
                          order.paymentMethod == 'Xendit'
                              ? 'Cancel payment'
                              : 'Cancel order',
                        ),
                      ),
                    if (order.status == 'pending' &&
                        order.paymentMethod == 'Xendit' &&
                        order.paymentStatus == 'paid')
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.lock_outline_rounded),
                        label: Text('Paid • cancellation unavailable'),
                      ),
                    if (order.status == 'cancelled')
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.cancel_rounded),
                        label: Text('Order cancelled'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
