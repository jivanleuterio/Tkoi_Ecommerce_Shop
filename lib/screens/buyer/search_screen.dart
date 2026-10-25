import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_categories.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/cart_action.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_card.dart';
import 'product_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Future<List<Product>>? _results;
  Timer? _timer;
  String _category = 'All';

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _results = value.trim().isEmpty && _category == 'All'
            ? null
            : ProductService().getProducts(search: value, category: _category);
      });
    });
  }

  void _selectCategory(String category) {
    setState(() => _category = category);
    _search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover fish'),
        actions: const [CartAction(), SizedBox(width: 6)],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: const BoxDecoration(gradient: AppColors.creamGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What are you looking for?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Fish name, species, or variety',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              _search('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: fishCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (_, index) {
                      final category = fishCategories[index];
                      return ChoiceChip(
                        label: Text(category),
                        selected: category == _category,
                        onSelected: (_) => _selectCategory(category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _results == null
                ? const EmptyState(
                    icon: Icons.manage_search,
                    title: 'Find your next fish',
                    message: 'Search by listing name or species.',
                  )
                : FutureBuilder<List<Product>>(
                    future: _results,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const TkoiLoadingView(
                          message: 'Searching the pond...',
                        );
                      }
                      if (snapshot.hasError) {
                        return ErrorView(error: snapshot.error!);
                      }
                      final products = snapshot.data ?? [];
                      if (products.isEmpty) {
                        return const EmptyState(
                          icon: Icons.search_off,
                          title: 'No matches',
                          message: 'Try a different fish name.',
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: .62,
                            ),
                        itemCount: products.length,
                        itemBuilder: (_, index) => ProductCard(
                          product: products[index],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsScreen(
                                productId: products[index].id,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
