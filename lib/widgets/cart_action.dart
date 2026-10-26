import 'package:flutter/material.dart';

import '../screens/buyer/cart_screen.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';

class CartAction extends StatefulWidget {
  const CartAction({super.key});

  @override
  State<CartAction> createState() => _CartActionState();
}

class _CartActionState extends State<CartAction> {
  late Future<int> _count;

  @override
  void initState() {
    super.initState();
    _count = _loadCount();
    CartService.revision.addListener(_handleCartChanged);
  }

  Future<int> _loadCount() => CartService()
      .getCart()
      .then((items) => items.fold(0, (sum, item) => sum + item.quantity))
      .catchError((_) => 0);

  void _refreshCount() {
    _count = _loadCount();
  }

  void _handleCartChanged() {
    if (!mounted) return;
    setState(_refreshCount);
  }

  @override
  void dispose() {
    CartService.revision.removeListener(_handleCartChanged);
    super.dispose();
  }

  Future<void> _openCart() async {
    setState(() {
      _refreshCount();
    });
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
    if (mounted) {
      setState(() {
        _refreshCount();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _count,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Shopping cart',
          onPressed: _openCart,
          icon: Badge(
            isLabelVisible: count > 0,
            backgroundColor: AppColors.vermilion,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
        );
      },
    );
  }
}
