import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/favorite_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_card_new.dart';
import 'product_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = FavoriteService().getFavorites();
  }

  Future<void> _refresh() async {
    setState(() {
      _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My favorites')),
    body: FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TkoiLoadingView(message: 'Gathering your favorites...');
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, onRetry: _refresh);
        }
        final products = snapshot.data ?? const [];
        if (products.isEmpty) {
          return const EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No favorites yet',
            message: 'Tap the heart on a fish to save it here.',
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .62,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => ProductCard(
              product: products[index],
              onTap: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductDetailsScreen(productId: products[index].id),
                  ),
                );
                if (mounted) _refresh();
              },
            ),
          ),
        );
      },
    ),
  );
}
