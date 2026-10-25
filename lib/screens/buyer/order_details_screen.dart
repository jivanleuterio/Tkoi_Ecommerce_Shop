import 'package:flutter/material.dart';

import '../../models/market_order.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_visuals.dart';
import '../../utils/formatters.dart';
import '../../widgets/safe_network_image.dart';
import 'chat_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final MarketOrder order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _openingChat = false;

  Future<void> _chatWithSeller() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final conversationId = await ChatService().getOrCreateConversation(
        sellerId: widget.order.sellerId,
        productId: widget.order.items
            .map((item) => item.productId)
            .whereType<String>()
            .firstOrNull,
        orderId: widget.order.id,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conversationId),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.waterGradient,
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order ${order.id.substring(0, 8).toUpperCase()}',
                  style: TextStyle(color: Colors.white.withValues(alpha: .8)),
                ),
                const SizedBox(height: 12),
                Chip(
                  label: Text(order.status.replaceAll('_', ' ')),
                  avatar: const Icon(Icons.local_shipping_outlined, size: 17),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Purchased fish', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SafeNetworkImage(
                            url: item.imageUrl,
                            fallbackAsset: FishVisuals.forFish(
                              name: item.productName,
                            ),
                            width: 64,
                            height: 64,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${item.quantity} × ${peso(item.unitPrice)}',
                                  style: const TextStyle(
                                    color: AppColors.softGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            peso(item.quantity * item.unitPrice),
                            style: const TextStyle(
                              color: AppColors.koiOrange,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Payment'),
                  subtitle: Text(order.paymentLabel),
                  trailing: Text(
                    peso(order.total),
                    style: const TextStyle(
                      color: AppColors.koiOrange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Delivery address'),
                  subtitle: Text(order.deliveryAddress),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Placed'),
                  subtitle: Text(
                    MaterialLocalizations.of(context)
                        .formatFullDate(order.createdAt.toLocal()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _openingChat ? null : _chatWithSeller,
            icon: _openingChat
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline_rounded),
            label: Text(
              _openingChat ? 'Opening conversation...' : 'Chat with Seller',
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Order actions such as payment, cancellation, received confirmation, reviews, and returns remain available on the My orders card.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.softGray),
          ),
        ],
      ),
    );
  }
}
