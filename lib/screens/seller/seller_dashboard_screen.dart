import 'package:flutter/material.dart';

import '../../models/market_order.dart';
import '../../models/product.dart';
import '../../models/seller_dashboard_stats.dart';
import '../../models/seller_wallet.dart';
import '../../models/shop.dart';
import '../../services/chat_service.dart';
import '../../services/order_service.dart';
import '../../services/product_service.dart';
import '../../services/seller_dashboard_service.dart';
import '../../services/seller_wallet_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_visuals.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/cart_action.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';
import '../../widgets/seller_sales_chart.dart';
import '../buyer/shop_details_screen.dart';
import '../buyer/chat_inbox_screen.dart';
import '../buyer/product_details_screen.dart';
import '../buyer/help_support_screen.dart';
import 'product_form_screen.dart';
import 'earnings_screen.dart';
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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listingsKey = GlobalKey();
  late Future<List<Product>> _future;
  late Future<List<MarketOrder>> _ordersFuture;
  late Future<int> _unreadChatsFuture;
  late Future<SellerWalletSummary> _walletFuture;
  late Future<SellerDashboardStats?> _statsFuture;
  int _salesDays = 7;
  bool _showLowStockOnly = false;
  bool _showModeratedOnly = false;

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
    _unreadChatsFuture = ChatService().getInbox().then(
      (items) => items.where((item) => item.unreadCount > 0).length,
    );
    _walletFuture = SellerWalletService().getSummary(widget.shop.id);
    _statsFuture = SellerDashboardService().getStats(
      widget.shop.id,
      days: _salesDays,
    );
  }

  void _refresh() {
    setState(() {
      _load();
    });
  }

  Future<void> _openChats() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ChatInboxScreen()),
    );
    if (mounted) _refresh();
  }

  void _openLowStockListings() {
    setState(() {
      _showLowStockOnly = true;
      _showModeratedOnly = false;
    });
    _scrollToListings();
  }

  void _openModeratedListings() {
    setState(() {
      _showModeratedOnly = true;
      _showLowStockOnly = false;
    });
    _scrollToListings();
  }

  void _scrollToListings() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final listingsContext = _listingsKey.currentContext;
      if (listingsContext != null) {
        Scrollable.ensureVisible(
          listingsContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: .05,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _duplicate(Product product) async {
    try {
      await ProductService().duplicateProduct(product);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} was duplicated as a hidden listing.'),
        ),
      );
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
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                      builder: (_) => ShopDetailsScreen(
                                        shopId: widget.shop.id,
                                      ),
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
              const SizedBox(height: 12),
              FutureBuilder<SellerWalletSummary>(
                future: _walletFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                        title: const Text('Earnings wallet'),
                        subtitle: const Text(
                          'Run migration 05 to enable seller earnings.',
                        ),
                        trailing: const Icon(Icons.info_outline_rounded),
                      ),
                    );
                  }
                  final summary = snapshot.data ?? SellerWalletSummary.empty;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: snapshot.hasData
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EarningsScreen(shop: widget.shop),
                              ),
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Earnings',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 18,
                              runSpacing: 10,
                              children: [
                                _WalletMetric(
                                  label: 'Available',
                                  value: pesoCentavos(
                                    summary.availableCentavos,
                                  ),
                                ),
                                _WalletMetric(
                                  label: 'Pending',
                                  value: pesoCentavos(summary.pendingCentavos),
                                ),
                                _WalletMetric(
                                  label: 'Earned',
                                  value: pesoCentavos(
                                    summary.totalEarnedCentavos,
                                  ),
                                ),
                                _WalletMetric(
                                  label: 'Withdrawn',
                                  value: pesoCentavos(
                                    summary.totalWithdrawnCentavos,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
                      final products =
                          productSnapshot.data ?? const <Product>[];
                      final orders =
                          orderSnapshot.data ?? const <MarketOrder>[];
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.5,
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
                            label: 'Awaiting',
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
              const SizedBox(height: 22),
              FutureBuilder<List<Product>>(
                future: _future,
                builder: (context, productSnapshot) {
                  return FutureBuilder<List<MarketOrder>>(
                    future: _ordersFuture,
                    builder: (context, orderSnapshot) {
                      return FutureBuilder<int>(
                        future: _unreadChatsFuture,
                        builder: (context, chatSnapshot) {
                          return FutureBuilder<SellerDashboardStats?>(
                            future: _statsFuture,
                            builder: (context, statsSnapshot) =>
                                _DashboardInsights(
                                  products: productSnapshot.data ?? const [],
                                  orders: orderSnapshot.data ?? const [],
                                  unreadChats: chatSnapshot.data ?? 0,
                                  stats: statsSnapshot.data,
                                  salesDays: _salesDays,
                                  onSalesDaysChanged: (value) {
                                    if (value == _salesDays) return;
                                    setState(() {
                                      _salesDays = value;
                                      _statsFuture = SellerDashboardService()
                                          .getStats(
                                            widget.shop.id,
                                            days: value,
                                          );
                                    });
                                  },
                                  onOpenOrders: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SellerOrdersScreen(shop: widget.shop),
                                    ),
                                  ),
                                  onOpenChats: _openChats,
                                  onOpenLowStock: _openLowStockListings,
                                  onOpenModerated: _openModeratedListings,
                                ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              Padding(
                key: _listingsKey,
                padding: const EdgeInsets.only(top: 22, bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showModeratedOnly
                            ? 'Listings needing review'
                            : _showLowStockOnly
                            ? 'Low-stock listings'
                            : 'Your fish listings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (_showLowStockOnly || _showModeratedOnly)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _showLowStockOnly = false;
                          _showModeratedOnly = false;
                        }),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Show all'),
                      ),
                  ],
                ),
              ),
              FutureBuilder<List<Product>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: TkoiLoadingView(
                        message: 'Loading your listings...',
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return ErrorView(error: snapshot.error!, onRetry: _refresh);
                  }
                  final allProducts = snapshot.data ?? [];
                  if (allProducts.isEmpty) {
                    return const EmptyState(
                      icon: Icons.add_business_outlined,
                      title: 'No listings yet',
                      message: 'Use “Add fish” to publish your first listing.',
                    );
                  }
                  final products = _showModeratedOnly
                      ? allProducts
                            .where((product) => product.isModerated)
                            .toList()
                      : _showLowStockOnly
                      ? allProducts
                            .where(
                              (product) =>
                                  product.quantity <= 3 &&
                                  product.status != 'hidden',
                            )
                            .toList()
                      : allProducts;
                  if (products.isEmpty) {
                    return EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: _showModeratedOnly
                          ? 'No moderated listings'
                          : 'No low-stock listings',
                      message: _showModeratedOnly
                          ? 'Your listings have no moderation restrictions.'
                          : 'All visible fish listings have enough stock.',
                    );
                  }
                  return Column(
                    children: products.map((product) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailsScreen(productId: product.id),
                              ),
                            ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (product.isModerated) ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.vermilion
                                                  .withValues(alpha: .08),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.moderationStatus
                                                      .replaceAll('_', ' '),
                                                  style: const TextStyle(
                                                    color: AppColors.vermilion,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                if (product
                                                    .moderationReason
                                                    .isNotEmpty)
                                                  Text(
                                                    product.moderationReason,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                TextButton.icon(
                                                  onPressed: () => Navigator.push<void>(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          CreateSupportTicketScreen(
                                                            initialCategory:
                                                                'appeal',
                                                            initialSubject:
                                                                'Appeal listing moderation: ${product.name}',
                                                            productId:
                                                                product.id,
                                                            shopId:
                                                                product.shopId,
                                                            categoryLocked:
                                                                true,
                                                          ),
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.support_agent,
                                                    size: 17,
                                                  ),
                                                  label: const Text('Appeal'),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${peso(product.price)} • ${product.quantity} in stock',
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 4,
                                          children: [
                                            _ListingMetric(
                                              icon: Icons.shopping_bag_outlined,
                                              label:
                                                  '${product.soldCount} sold',
                                            ),
                                            _ListingMetric(
                                              icon: Icons
                                                  .favorite_outline_rounded,
                                              label: '${product.heartCount}',
                                            ),
                                            _ListingMetric(
                                              icon: Icons.star_outline_rounded,
                                              label: product.totalReviews == 0
                                                  ? 'No ratings'
                                                  : product.averageRating
                                                        .toStringAsFixed(1),
                                            ),
                                          ],
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
                                              await ProductService()
                                                  .updateStatus(
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
                                      } else if (action == 'duplicate') {
                                        await _duplicate(product);
                                      } else {
                                        final changed =
                                            await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ProductFormScreen(
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
                                        value: 'duplicate',
                                        child: Text('Duplicate'),
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
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ListingMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.softGray),
      const SizedBox(width: 3),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _WalletMetric extends StatelessWidget {
  final String label;
  final String value;

  const _WalletMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.pondBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
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
                maxLines: 2,
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

class _DashboardInsights extends StatelessWidget {
  final List<Product> products;
  final List<MarketOrder> orders;
  final int unreadChats;
  final SellerDashboardStats? stats;
  final int salesDays;
  final ValueChanged<int> onSalesDaysChanged;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenLowStock;
  final VoidCallback onOpenModerated;

  const _DashboardInsights({
    required this.products,
    required this.orders,
    required this.unreadChats,
    required this.stats,
    required this.salesDays,
    required this.onSalesDaysChanged,
    required this.onOpenOrders,
    required this.onOpenChats,
    required this.onOpenLowStock,
    required this.onOpenModerated,
  });

  List<SellerSalesPoint> get _localPoints {
    final today = DateTime.now();
    return [
      for (var offset = salesDays - 1; offset >= 0; offset--)
        () {
          final day = DateTime(today.year, today.month, today.day - offset);
          final matching = orders.where((order) {
            final created = order.createdAt.toLocal();
            return order.status == 'completed' &&
                created.year == day.year &&
                created.month == day.month &&
                created.day == day.day;
          });
          return SellerSalesPoint(
            label: salesDays == 7
                ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1]
                : '${day.day}',
            revenueCentavos: matching.fold<int>(
              0,
              (sum, order) => sum + (order.total * 100).round(),
            ),
            orderCount: matching.length,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localToShip = orders.where((order) {
      return const {
        'confirmed',
        'preparing',
        'ready_for_delivery',
      }.contains(order.status);
    }).length;
    final localReturns = orders.where((order) {
      return const {
        'requested',
        'approved',
        'received',
      }.contains(order.returnRequest?.status);
    }).length;
    final localLowStock = products
        .where((product) => product.quantity <= 3 && product.status != 'hidden')
        .length;
    final moderated = products.where((product) => product.isModerated).length;
    final reviewedProducts = products
        .where((product) => product.totalReviews > 0)
        .toList();
    final localReviewCount = reviewedProducts.fold<int>(
      0,
      (sum, product) => sum + product.totalReviews,
    );
    final localRating = localReviewCount == 0
        ? 0.0
        : reviewedProducts.fold<double>(
                0,
                (sum, product) =>
                    sum + product.averageRating * product.totalReviews,
              ) /
              localReviewCount;
    final topProducts = [...products]
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final recentReviews = orders
        .where((order) => order.review != null)
        .take(3)
        .toList();
    final toShip = stats?.toShip ?? localToShip;
    final returns = stats?.activeReturns ?? localReturns;
    final lowStock = stats?.lowStock ?? localLowStock;
    final effectiveUnread = stats?.unreadChats ?? unreadChats;
    final reviewCount = stats?.totalReviews ?? localReviewCount;
    final rating = stats?.averageRating ?? localRating;
    final effectivePoints = stats?.salesPoints ?? _localPoints;
    final topName =
        stats?.topProducts.firstOrNull?.name ?? topProducts.firstOrNull?.name;
    final topSold =
        stats?.topProducts.firstOrNull?.soldCount ??
        topProducts.firstOrNull?.soldCount;
    final completedOrders = orders
        .where((order) => order.status == 'completed')
        .toList();
    final localRevenue = completedOrders.fold<int>(
      0,
      (sum, order) => sum + (order.total * 100).round(),
    );
    final totalRevenue = stats?.totalRevenueCentavos ?? localRevenue;
    final totalCompleted = stats?.completedOrders ?? completedOrders.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Needs your action',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Orders to ship',
                  count: toShip,
                  onTap: onOpenOrders,
                ),
                _ActionRow(
                  icon: Icons.assignment_return_outlined,
                  label: 'Return / refund requests',
                  count: returns,
                  onTap: onOpenOrders,
                ),
                _ActionRow(
                  icon: Icons.mark_chat_unread_outlined,
                  label: 'Unread chats',
                  count: effectiveUnread,
                  onTap: onOpenChats,
                ),
                _ActionRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Low-stock listings',
                  count: lowStock,
                  onTap: onOpenLowStock,
                ),
                _ActionRow(
                  icon: Icons.policy_outlined,
                  label: 'Moderated listings',
                  count: moderated,
                  onTap: onOpenModerated,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Sales overview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7D')),
                ButtonSegment(value: 30, label: Text('30D')),
              ],
              selected: {salesDays},
              onSelectionChanged: (values) => onSalesDaysChanged(values.first),
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _WalletMetric(
                        label: 'Total revenue',
                        value: pesoCentavos(totalRevenue),
                      ),
                    ),
                    Text('$totalCompleted completed orders'),
                  ],
                ),
                // The chart is display-only. Excluding it from pointer hit
                // testing ensures a drag that begins on a bar always belongs
                // to the dashboard's single vertical scroll view.
                IgnorePointer(child: SellerSalesChart(points: effectivePoints)),
                Text(
                  'Includes completed COD and Xendit orders.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Shop insights', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.star_rounded,
                title: rating == 0
                    ? 'No rating yet'
                    : rating.toStringAsFixed(1),
                subtitle: '$reviewCount product reviews',
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightCard(
                icon: Icons.emoji_events_outlined,
                title: topName ?? 'No sales yet',
                subtitle: topSold == null ? 'Top product' : '$topSold sold',
                color: AppColors.pondBlue,
              ),
            ),
          ],
        ),
        if ((stats?.recentReviews.isNotEmpty ?? false) ||
            recentReviews.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent reviews',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (stats case final value?)
                    for (final review in value.recentReviews)
                      _RecentReviewTile(
                        rating: review.rating,
                        buyerName: review.buyerName,
                        comment: review.comment,
                      )
                  else
                    for (final order in recentReviews)
                      _RecentReviewTile(
                        rating: order.review!.rating,
                        buyerName: order.buyerName,
                        comment: order.review!.comment,
                      ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      backgroundColor: AppColors.cream,
      child: Icon(icon, color: AppColors.koiOrange),
    ),
    title: Text(label),
    trailing: Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: const Icon(Icons.chevron_right_rounded),
    ),
    onTap: onTap,
  );
}

class _RecentReviewTile extends StatelessWidget {
  final int rating;
  final String buyerName;
  final String comment;

  const _RecentReviewTile({
    required this.rating,
    required this.buyerName,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.star_rounded, color: AppColors.gold),
    title: Text('$rating/5 • $buyerName'),
    subtitle: Text(
      comment.isEmpty ? 'No written comment' : comment,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
