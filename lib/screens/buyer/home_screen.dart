import 'package:flutter/material.dart';

import '../../models/app_profile.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/fish_categories.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/cart_action.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_card.dart';
import '../../widgets/safe_network_image.dart';
import 'product_details_screen.dart';
import 'search_screen.dart';
import 'shop_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'All';
  late Future<List<Product>> _products;
  late Future<AppProfile> _profile;

  @override
  void initState() {
    super.initState();
    _load();
    _profile = ProfileService().getMyProfile();
  }

  void _load() {
    _products = ProductService().getProducts(category: _category);
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      _load();
    });
  }

  void _openProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(productId: product.id),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _load();
      _profile = ProfileService().getMyProfile();
    });
    await Future.wait([_products, _profile]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            TkoiBrandMark(size: 38),
            SizedBox(width: 10),
            Text('Tkoi'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search fish',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          const CartAction(),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.koiOrange,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FutureBuilder<AppProfile>(
                future: _profile,
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  return Row(
                    children: [
                      SafeNetworkImage(
                        url: profile?.avatarUrl,
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Good day,',
                              style: TextStyle(color: AppColors.softGray),
                            ),
                            Text(
                              profile?.fullName.isNotEmpty == true
                                  ? profile!.fullName
                                  : 'Fish keeper',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mist,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: AppColors.pondBlue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Local market',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.deepWater,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                readOnly: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
                decoration: InputDecoration(
                  hintText: 'Search koi, betta, goldfish...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.deepWater,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MarketHero(onExplore: () => _selectCategory('Koi')),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TkoiSectionHeader(
                title: 'Browse categories',
                subtitle: 'Find the right fish for your pond or aquarium',
                action: TextButton(
                  onPressed: () => _selectCategory('All'),
                  child: const Text('View all'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: fishCategories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final category = fishCategories[index];
                  return ChoiceChip(
                    avatar: category == _category
                        ? const Icon(
                            Icons.water_drop_rounded,
                            size: 16,
                            color: AppColors.koiOrange,
                          )
                        : null,
                    label: Text(category),
                    selected: category == _category,
                    onSelected: (_) => _selectCategory(category),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            FutureBuilder<List<Product>>(
              future: _products,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ProductGridSkeleton();
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 330,
                    child: ErrorView(
                      error: snapshot.error!,
                      onRetry: () => setState(() {
                        _load();
                      }),
                    ),
                  );
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const SizedBox(
                    height: 360,
                    child: EmptyState(
                      icon: Icons.water,
                      title: 'No fish here yet',
                      message: 'Try another category or pull down to refresh.',
                    ),
                  );
                }
                return _MarketplaceContent(
                  products: products,
                  category: _category,
                  openProduct: _openProduct,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketHero extends StatelessWidget {
  final VoidCallback onExplore;

  const _MarketHero({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 178,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.koiGradient,
        borderRadius: BorderRadius.circular(AppRadii.large),
        boxShadow: AppColors.softShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -25,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .12),
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: -12,
            child: Transform.rotate(
              angle: -.22,
              child: Icon(
                Icons.set_meal_rounded,
                size: 118,
                color: Colors.white.withValues(alpha: .28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    'FRESH FINDS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppColors.sumi,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bring your pond\nto life',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: onExplore,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore koi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceContent extends StatelessWidget {
  final List<Product> products;
  final String category;
  final ValueChanged<Product> openProduct;

  const _MarketplaceContent({
    required this.products,
    required this.category,
    required this.openProduct,
  });

  @override
  Widget build(BuildContext context) {
    final shops = <String, Product>{};
    for (final product in products) {
      shops.putIfAbsent(product.shopId, () => product);
    }
    final featured = products.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const TkoiSectionHeader(
            title: 'Featured fish',
            subtitle: 'Beautiful picks from Tkoi sellers',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 286,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) => SizedBox(
              width: 184,
              child: ProductCard(
                product: featured[index],
                onTap: () => openProduct(featured[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (shops.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TkoiSectionHeader(
              title: 'Nearby sellers',
              subtitle: 'Fish shops currently listing near you',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: shops.length > 6 ? 6 : shops.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final product = shops.values.elementAt(index);
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDetailsScreen(shopId: product.shopId),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.mist,
                          child: Icon(
                            Icons.storefront_rounded,
                            color: AppColors.pondBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.sellerLocation,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.softGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TkoiSectionHeader(
            title: category == 'All' ? 'Recently added' : '$category listings',
            subtitle:
                '${products.length} available listing${products.length == 1 ? '' : 's'}',
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                ? 3
                : 2;
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .62,
              ),
              itemCount: products.length,
              itemBuilder: (_, index) => ProductCard(
                product: products[index],
                onTap: () => openProduct(products[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}
