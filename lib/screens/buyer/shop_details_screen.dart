import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/shop.dart';
import '../../services/product_service.dart';
import '../../services/shop_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_card.dart';
import '../../widgets/safe_network_image.dart';
import 'product_details_screen.dart';

class ShopDetailsScreen extends StatelessWidget {
  final String shopId;

  const ShopDetailsScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop details')),
      body: FutureBuilder<Shop>(
        future: ShopService().getShop(shopId),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Opening this koi shop...');
          }
          if (shopSnapshot.hasError) {
            return ErrorView(error: shopSnapshot.error!);
          }
          final shop = shopSnapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.waterGradient,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  boxShadow: AppColors.softShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SafeNetworkImage(
                        url: shop.logoUrl,
                        width: 82,
                        height: 82,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            Text(
                              'Owner: ${shop.ownerName}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .8),
                              ),
                            ),
                            Text(
                              shop.location,
                              style: const TextStyle(color: AppColors.aqua),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              shop.description,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${shop.contactNumber} • ${shop.email}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .76),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Available fish',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<Product>>(
                future: ProductService().getProducts(shopId: shopId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: TkoiLoadingView(
                        message: 'Loading available fish...',
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return ErrorView(error: snapshot.error!);
                  }
                  final products = snapshot.data ?? [];
                  if (products.isEmpty) {
                    return const EmptyState(
                      icon: Icons.set_meal_outlined,
                      title: 'No available fish',
                      message: 'This shop has no active listings right now.',
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
            ],
          );
        },
      ),
    );
  }
}
