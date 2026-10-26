import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class RestrictedAccountScreen extends StatelessWidget {
  final AdminAccessContext access;
  final VoidCallback? onAppeal;

  const RestrictedAccountScreen({
    super.key,
    required this.access,
    this.onAppeal,
  });

  @override
  Widget build(BuildContext context) {
    final until = access.restrictedUntil?.toLocal();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.vermilion.withValues(alpha: .1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: AppColors.vermilion,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Account ${access.status}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      access.reasonPublic?.trim().isNotEmpty == true
                          ? access.reasonPublic!
                          : 'Your account currently has restricted access.',
                      textAlign: TextAlign.center,
                    ),
                    if (until != null) ...[
                      const SizedBox(height: 8),
                      Text('Restriction ends: $until'),
                    ],
                    const SizedBox(height: 20),
                    if (onAppeal != null)
                      FilledButton.icon(
                        onPressed: onAppeal,
                        icon: const Icon(Icons.support_agent),
                        label: const Text('Appeal restriction'),
                      ),
                    TextButton(
                      onPressed: AuthService().signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
