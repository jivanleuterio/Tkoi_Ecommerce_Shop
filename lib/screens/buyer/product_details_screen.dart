import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../services/chat_service.dart';
import '../../services/favorite_service.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_visuals.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_reviews_section.dart';
import '../../widgets/safe_network_image.dart';
import '../../widgets/tkoi_button.dart';
import 'checkout_screen.dart';
import 'chat_screen.dart';
import 'shop_details_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Future<Product> _future;
  bool _adding = false;
  bool _favoriteBusy = false;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = ProductService().getProduct(widget.productId);
  }

  Future<void> _add(Product product) async {
    setState(() => _adding = true);
    try {
      await CartService().add(product);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Added to cart.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _buyNow(Product product) async {
    final item = CartItem(id: 'buy-now', quantity: 1, product: product);
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CheckoutScreen(items: [item], buyNowProductId: product.id),
      ),
    );
  }

  Future<void> _toggleFavorite(Product product) async {
    if (_favoriteBusy) return;
    final next = !product.isFavorite;
    setState(() {
      _favoriteBusy = true;
      _future = Future.value(
        product.copyWith(
          isFavorite: next,
          heartCount: next
              ? product.heartCount + 1
              : (product.heartCount > 0 ? product.heartCount - 1 : 0),
        ),
      );
    });
    try {
      await FavoriteService().setFavorite(product.id, next);
    } catch (error) {
      if (mounted) {
        setState(() {
          _future = Future.value(product);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _chatWithSeller(Product product) async {
    if (product.sellerId == Supabase.instance.client.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself.')),
      );
      return;
    }
    try {
      final conversationId = await ChatService().getOrCreateConversation(
        sellerId: product.sellerId,
        productId: product.id,
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
    }
  }

  Widget _detail(String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.mist.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(AppRadii.small),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.softGray,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fish details'),
        actions: [
          FutureBuilder<Product>(
            future: _future,
            builder: (context, snapshot) {
              final product = snapshot.data;
              return IconButton(
                tooltip: product?.isFavorite == true
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: product == null || _favoriteBusy
                    ? null
                    : () => _toggleFavorite(product),
                icon: Icon(
                  product?.isFavorite == true
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: product?.isFavorite == true
                      ? AppColors.vermilion
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<Product>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Loading fish details...');
          }
          if (snapshot.hasError) return ErrorView(error: snapshot.error!);
          final product = snapshot.data!;
          final imageUrl = product.imageUrls.isEmpty
              ? null
              : product.imageUrls[_imageIndex.clamp(
                  0,
                  product.imageUrls.length - 1,
                )];

          return ListView(
            padding: const EdgeInsets.only(bottom: 130),
            children: [
              Stack(
                children: [
                  SafeNetworkImage(
                    url: imageUrl,
                    fallbackAsset: FishVisuals.forFish(
                      category: product.category,
                      species: product.species,
                      name: product.name,
                    ),
                    width: double.infinity,
                    height: 330,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadii.large),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sumi.withValues(alpha: .78),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        '${_imageIndex + 1} / ${product.imageUrls.isEmpty ? 1 : product.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (product.imageUrls.length > 1)
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(10),
                    scrollDirection: Axis.horizontal,
                    itemCount: product.imageUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => InkWell(
                      onTap: () => setState(() => _imageIndex = index),
                      child: SafeNetworkImage(
                        url: product.imageUrls[index],
                        fallbackAsset: FishVisuals.forFish(
                          category: product.category,
                          species: product.species,
                          name: product.name,
                        ),
                        width: 62,
                        height: 62,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        Chip(
                          avatar: const Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: AppColors.success,
                          ),
                          label: Text(
                            product.isAvailable ? 'Available' : 'Unavailable',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      peso(product.price),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.koiOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${product.species} • ${product.category}',
                      style: const TextStyle(color: AppColors.softGray),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatChip(
                          icon: Icons.star_rounded,
                          color: AppColors.gold,
                          label: product.totalReviews == 0
                              ? 'No ratings yet'
                              : '${product.averageRating.toStringAsFixed(1)} (${compactCount(product.totalReviews)})',
                        ),
                        _StatChip(
                          icon: Icons.shopping_bag_outlined,
                          color: AppColors.koiOrange,
                          label: '${compactCount(product.soldCount)} sold',
                        ),
                        _StatChip(
                          icon: Icons.favorite_rounded,
                          color: AppColors.vermilion,
                          label: '${compactCount(product.heartCount)} hearts',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.pondBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ships from ${product.sellerLocation}',
                            style: const TextStyle(
                              color: AppColors.deepWater,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Fish profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _detail('Species', product.species),
                    _detail('Category', product.category),
                    _detail('Size', product.size),
                    _detail(
                      'Age',
                      product.ageMonths == null
                          ? 'Unknown'
                          : '${product.ageMonths} months',
                    ),
                    _detail('Sex', product.sex),
                    _detail('Health', product.healthCondition),
                    _detail('Stock', '${product.quantity} available'),
                    _detail('Location', product.sellerLocation),
                    _detail('Status', product.status),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About this fish',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(product.description),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.cream,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: AppColors.koiOrange,
                          ),
                        ),
                        title: Text(product.shopName),
                        subtitle: Text(product.sellerLocation),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ShopDetailsScreen(shopId: product.shopId),
                          ),
                        ),
                      ),
                    ),
                    if (product.sellerId !=
                        Supabase.instance.client.auth.currentUser?.id) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _chatWithSeller(product),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Chat with Seller'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ProductReviewsSection(product: product),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<Product>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final product = snapshot.data!;
          final isOwn =
              product.sellerId == Supabase.instance.client.auth.currentUser?.id;
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x18172033),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: (!product.isAvailable || isOwn)
                  ? TkoiButton(
                      onPressed: null,
                      label: isOwn ? 'This is your listing' : 'Not available',
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _adding ? null : () => _add(product),
                            icon: const Icon(Icons.add_shopping_cart),
                            label: Text(_adding ? 'Adding...' : 'Add to cart'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TkoiButton(
                            onPressed: _adding ? null : () => _buyNow(product),
                            icon: Icons.flash_on_rounded,
                            label: 'Buy now',
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
