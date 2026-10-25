import 'package:flutter/material.dart';

import '../../models/app_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/error_view.dart';
import '../../widgets/cart_action.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';
import '../auth/phone_verification_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'chat_inbox_screen.dart';
import 'orders_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<AppProfile> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ProfileService().getMyProfile();
  }

  void _refresh() {
    setState(() {
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: const [CartAction(), SizedBox(width: 6)],
      ),
      body: FutureBuilder<AppProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Loading your profile...');
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _refresh);
          }
          final profile = snapshot.data!;
          final auth = AuthService();
          final phoneVerified = auth.isPhoneVerified;
          final displayedPhone = phoneVerified
              ? auth.currentUser?.phone ?? profile.mobileNumber
              : profile.mobileNumber;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.waterGradient,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: SafeNetworkImage(
                        url: profile.avatarUrl,
                        width: 92,
                        height: 92,
                        borderRadius: BorderRadius.circular(46),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.fullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.white),
                    ),
                    Text(
                      '@${profile.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Account details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(profile.email),
                    ),
                    ListTile(
                      leading: Icon(
                        phoneVerified
                            ? Icons.verified_outlined
                            : Icons.phone_outlined,
                        color: phoneVerified ? AppColors.success : null,
                      ),
                      title: const Text('Mobile number'),
                      subtitle: Text(displayedPhone),
                      trailing: Text(
                        phoneVerified ? 'Verified' : 'Not verified',
                        style: TextStyle(
                          color: phoneVerified
                              ? AppColors.success
                              : AppColors.koiOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Address'),
                      subtitle: Text(profile.address),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.cream,
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.koiOrange,
                        ),
                      ),
                      title: const Text('My orders'),
                      subtitle: const Text(
                        'Track purchases and payment status',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      ),
                    ),
                    const Divider(indent: 72),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.mist,
                        child: Icon(
                          Icons.forum_outlined,
                          color: AppColors.pondBlue,
                        ),
                      ),
                      title: const Text('Messages'),
                      subtitle: const Text('Chat with buyers and sellers'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatInboxScreen(),
                        ),
                      ),
                    ),
                    const Divider(indent: 72),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.cream,
                        child: Icon(
                          Icons.favorite_outline_rounded,
                          color: AppColors.vermilion,
                        ),
                      ),
                      title: const Text('My favorites'),
                      subtitle: const Text('Fish you saved for later'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      ),
                    ),
                    const Divider(indent: 72),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.mist,
                        child: Icon(
                          Icons.shield_outlined,
                          color: AppColors.pondBlue,
                        ),
                      ),
                      title: const Text('Account security'),
                      subtitle: Text(
                        phoneVerified
                            ? 'Email and phone verified'
                            : 'Email verified • Phone verification available',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(profile: profile),
                    ),
                  );
                  if (changed == true) _refresh();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
              if (!phoneVerified) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final verified = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PhoneVerificationScreen(),
                      ),
                    );
                    if (verified == true) _refresh();
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Verify phone to start selling'),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => AuthService().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tkoi uses email for sign-in. A verified phone number is required '
                'before an account can create or manage a fish shop.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          );
        },
      ),
    );
  }
}
