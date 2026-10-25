import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/favorite_service.dart';
import '../theme/app_colors.dart';
import '../utils/fish_visuals.dart';
import '../utils/formatters.dart';
import 'safe_network_image.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _pressed = false;
  late bool _favorite;
  late int _heartCount;
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    _favorite = widget.product.isFavorite;
    _heartCount = widget.product.heartCount;
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.isFavorite != widget.product.isFavorite) {
      _favorite = widget.product.isFavorite;
      _heartCount = widget.product.heartCount;
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    final next = !_favorite;
    setState(() {
      _favorite = next;
      _heartCount = next
          ? _heartCount + 1
          : (_heartCount > 0 ? _heartCount - 1 : 0);
      _favoriteBusy = true;
    });
    try {
      await FavoriteService().setFavorite(widget.product.id, next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _favorite = !next;
        _heartCount = next
            ? (_heartCount > 0 ? _heartCount - 1 : 0)
            : _heartCount + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update favorites: $error')),
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return AnimatedScale(
      scale: _pressed ? .975 : 1,
      duration: const Duration(milliseconds: 120),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SafeNetworkImage(
                      url: product.primaryImage,
                      fallbackAsset: FishVisuals.forFish(
                        category: product.category,
                        species: product.species,
                        name: product.name,
                      ),
                      width: double.infinity,
                      borderRadius: BorderRadius.zero,
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _Badge(
                        text: product.isAvailable ? 'Available' : 'Sold out',
                        color: product.isAvailable
                            ? AppColors.success
                            : AppColors.vermilion,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.white.withValues(alpha: .92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: _favorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onPressed: _favoriteBusy ? null : _toggleFavorite,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              _favorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              key: ValueKey(_favorite),
                              size: 20,
                              color: _favorite
                                  ? AppColors.vermilion
                                  : AppColors.sumi,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.sumi,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.species} • ${product.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.softGray,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      peso(product.price),
                      style: const TextStyle(
                        color: AppColors.koiOrange,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          product.totalReviews == 0
                              ? 'New'
                              : product.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${compactCount(product.soldCount)} sold',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.softGray,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.favorite_rounded,
                          size: 13,
                          color: AppColors.vermilion,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          compactCount(_heartCount),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.softGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _MetaLine(
                      icon: Icons.storefront_outlined,
                      text: product.shopName,
                    ),
                    const SizedBox(height: 2),
                    _MetaLine(
                      icon: Icons.location_on_outlined,
                      text: product.sellerLocation,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: AppColors.pondBlue),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: AppColors.softGray),
        ),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
