import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../models/shop.dart';
import '../../services/auth_service.dart';
import '../../services/shop_service.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../auth/phone_verification_screen.dart';
import '../seller/seller_dashboard_screen.dart';
import '../seller/shop_form_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class MainShell extends StatefulWidget {
  final AdminAccessContext? access;

  const MainShell({super.key, this.access});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _ordersRevision = 0;
  int _sellRevision = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const SearchScreen(),
      OrdersScreen(key: ValueKey(_ordersRevision)),
      SellerEntry(key: ValueKey(_sellRevision)),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (widget.access?.isSuspended == true)
            MaterialBanner(
              content: Text(
                widget.access?.reasonPublic?.trim().isNotEmpty == true
                    ? 'Account suspended: ${widget.access!.reasonPublic}'
                    : 'Your account is suspended. You can finish eligible existing orders and use Help & Support.',
              ),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
            if (value == 2) _ordersRevision++;
            if (value == 3) _sellRevision++;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.manage_search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Sell',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SellerEntry extends StatefulWidget {
  const SellerEntry({super.key});

  @override
  State<SellerEntry> createState() => _SellerEntryState();
}

class _SellerEntryState extends State<SellerEntry> {
  late Future<Shop?> _future;

  @override
  void initState() {
    super.initState();
    _future = ShopService().getMyShop();
  }

  void _reload() {
    setState(() {
      _future = ShopService().getMyShop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isPhoneVerified) {
      return PhoneVerificationScreen(onVerified: _reload);
    }
    return FutureBuilder<Shop?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TkoiLoadingView(message: 'Opening your shop...');
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, onRetry: _reload);
        }
        final shop = snapshot.data;
        return shop == null
            ? ShopFormScreen(onSaved: _reload)
            : SellerDashboardScreen(shop: shop, onShopChanged: _reload);
      },
    );
  }
}
