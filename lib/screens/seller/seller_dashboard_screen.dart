import 'package:flutter/material.dart';

import '../../models/market_order.dart';
import '../../models/product.dart';
import '../../models/shop.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_visuals.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/cart_action.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';
import '../buyer/shop_details_screen.dart';
import 'product_form_screen.dart';
import 'seller_orders_screen.dart';
import 'shop_form_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  final Shop shop;
  final VoidCallback onShopChanged;

  const SellerDashboardScreen({
    super.key,
    required this.shop,
    required this.onShopChanged,
  });

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late Future<List<Product>> _future;
  late Future<List<MarketOrder>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ProductService().getProducts(
      shopId: widget.shop.id,
      sellerView: true,
    );
    _ordersFuture = OrderService().getSellerOrders(widget.shop.id);
  }

  void _refresh() {
    setState(() {
      _load();
    });
  }

  Future<void> _delete(Product product) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('Delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ProductService().deleteProduct(product.id);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${product.name} was deleted.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller dashboard'),
        actions: [
          IconButton(
            tooltip: 'Received orders',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerOrdersScreen(shop: widget.shop),
              ),
            ),
          ),
          const CartAction(),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ProductFormScreen(shop: widget.shop),
            ),
          );
          if (changed == true) _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add fish'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SafeNetworkImage(
                    url: widget.shop.logoUrl,
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.shop.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(widget.shop.location),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ShopDetailsScreen(shopId: widget.shop.id),
                                ),
                              ),
                              child: const Text('View shop'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ShopFormScreen(shop: widget.shop),
                                  ),
                                );
                                if (changed == true) widget.onShopChanged();
                              },
                              child: const Text('Edit shop'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Shop performance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Product>>(
            future: _future,
            builder: (context, productSnapshot) {
              return FutureBuilder<List<MarketOrder>>(
                future: _ordersFuture,
                builder: (context, orderSnapshot) {
                  final products = productSnapshot.data ?? const <Product>[];
                  final orders = orderSnapshot.data ?? const <MarketOrder>[];
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.65,
                    children: [
                      _StatCard(
                        label: 'Total products',
                        value: '${products.length}',
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.koiOrange,
                      ),
                      _StatCard(
                        label: 'Available',
                        value:
                            '${products.where((item) => item.isAvailable).length}',
                        icon: Icons.water_drop_outlined,
                        color: AppColors.pondBlue,
                      ),
                      _StatCard(
                        label: 'Pending orders',
                        value:
                            '${orders.where((item) => item.status == 'pending').length}',
                        icon: Icons.pending_actions_outlined,
                        color: AppColors.gold,
                      ),
                      _StatCard(
                        label: 'Completed',
                        value:
                            '${orders.where((item) => item.status == 'completed').length}',
                        icon: Icons.verified_outlined,
                        color: AppColors.success,
                      ),
                    ],
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 10),
            child: Text(
              'Your fish listings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          FutureBuilder<List<Product>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: TkoiLoadingView(message: 'Loading your listings...'),
                );
              }
              if (snapshot.hasError) {
                return ErrorView(error: snapshot.error!, onRetry: _refresh);
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return const EmptyState(
                  icon: Icons.add_business_outlined,
                  title: 'No listings yet',
                  message: 'Use “Add fish” to publish your first listing.',
                );
              }
              return Column(
                children: products.map((product) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            SafeNetworkImage(
                              url: product.primaryImage,
                              fallbackAsset: FishVisuals.forFish(
                                category: product.category,
                                species: product.species,
                                name: product.name,
                              ),
                              width: 72,
                              height: 72,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${peso(product.price)} • ${product.quantity} in stock',
                                  ),
                                  DropdownButton<String>(
                                    value: product.status,
                                    isDense: true,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'available',
                                        child: Text('Available'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'sold_out',
                                        child: Text('Sold out'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'hidden',
                                        child: Text('Hidden'),
                                      ),
                                    ],
                                    onChanged: (status) async {
                                      if (status == null) return;
                                      try {
                                        await ProductService().updateStatus(
                                          product.id,
                                          status,
                                        );
                                        _refresh();
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    friendlyError(error),
                                                  ),
                                                ),
                                              );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'delete') {
                                  await _delete(product);
                                } else {
                                  final changed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductFormScreen(
                                        shop: widget.shop,
                                        product: product,
                                      ),
                                    ),
                                  );
                                  if (changed == true) _refresh();
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: color.withValues(alpha: .2)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  height: 1,
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.softGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
