import 'package:flutter/material.dart';

import '../../models/admin_user.dart';
import '../../services/admin_moderation_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  String? _status;
  late Future<List<AdminUserSummary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    _future = AdminModerationService().getUsers(
      search: _search.text,
      status: _status,
    );
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _refresh(),
                decoration: const InputDecoration(
                  hintText: 'Search name or username',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String?>(
              tooltip: 'Filter status',
              onSelected: (value) {
                _status = value;
                _refresh();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: null, child: Text('All statuses')),
                PopupMenuItem(value: 'active', child: Text('Active')),
                PopupMenuItem(value: 'suspended', child: Text('Suspended')),
                PopupMenuItem(value: 'banned', child: Text('Banned')),
              ],
              icon: const Icon(Icons.filter_list),
            ),
            Text(_status ?? 'All'),
            IconButton(
              tooltip: 'Refresh accounts',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<AdminUserSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TkoiLoadingView(message: 'Loading accounts...');
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _refresh);
            }
            final users = snapshot.data ?? const [];
            if (users.isEmpty) {
              return const EmptyState(
                icon: Icons.people_outline,
                title: 'No accounts found',
                message: 'Try another search or status filter.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    child: ListTile(
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminUserDetailScreen(userId: user.userId),
                          ),
                        );
                        _refresh();
                      },
                      leading: ClipOval(
                        child: SafeNetworkImage(
                          url: user.avatarUrl,
                          width: 48,
                          height: 48,
                        ),
                      ),
                      title: Text(user.fullName),
                      subtitle: Text(
                        '@${user.username} | ${user.maskedEmail}\n'
                        '${user.isShopOwner ? 'Seller' : 'Buyer'} | ${user.orderCount} orders',
                      ),
                      isThreeLine: true,
                      trailing: Chip(label: Text(user.status)),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}
