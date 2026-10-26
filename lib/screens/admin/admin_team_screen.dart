import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../services/admin_access_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';

class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  late Future<List<AdminTeamMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminAccessService().getTeam();
  }

  void _reload() => setState(() => _future = AdminAccessService().getTeam());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AdminTeamMember>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const TkoiLoadingView(message: 'Loading admin team...');
      }
      if (snapshot.hasError) {
        return ErrorView(error: snapshot.error!, onRetry: _reload);
      }
      final members = snapshot.data ?? const [];
      if (members.isEmpty) {
        return const EmptyState(
          icon: Icons.admin_panel_settings_outlined,
          title: 'No admin accounts',
          message: 'Admin roles are granted only from the Supabase SQL Editor.',
        );
      }
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Read-only team'),
                  subtitle: Text(
                    'Roles can only be granted or revoked in Supabase.',
                  ),
                ),
              );
            }
            final member = members[index - 1];
            return Card(
              child: ListTile(
                leading: ClipOval(
                  child: SafeNetworkImage(
                    url: member.avatarUrl,
                    width: 46,
                    height: 46,
                  ),
                ),
                title: Text(member.fullName),
                subtitle: Text(
                  '${member.username.isEmpty ? 'No username' : '@${member.username}'} | '
                  '${member.role.replaceAll('_', ' ')}',
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
