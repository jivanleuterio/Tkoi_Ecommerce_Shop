import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../buyer/main_shell.dart';
import 'admin_team_screen.dart';
import 'admin_users_screen.dart';
import 'admin_tickets_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_content_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_finance_screen.dart';
import 'admin_audit_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminShell extends StatefulWidget {
  final AdminAccessContext access;

  const AdminShell({super.key, required this.access});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminSection {
  final String label;
  final IconData icon;
  final String permission;

  const _AdminSection(this.label, this.icon, this.permission);
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    var completed = false;
    try {
      await AuthService().signOut();
      completed = true;
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted && !completed) setState(() => _signingOut = false);
    }
  }

  List<_AdminSection> get _sections {
    final candidates = <_AdminSection>[
      const _AdminSection('Dashboard', Icons.dashboard_outlined, '*'),
      const _AdminSection('Users', Icons.people_outline, 'users.view'),
      const _AdminSection('Support', Icons.support_agent, 'tickets.view'),
      const _AdminSection('Reports', Icons.flag_outlined, 'reports.view'),
      const _AdminSection('Content', Icons.policy_outlined, 'content.moderate'),
      const _AdminSection('Orders', Icons.receipt_long_outlined, 'orders.view'),
      const _AdminSection('Finance', Icons.payments_outlined, 'wallet.view'),
      const _AdminSection('Audit', Icons.fact_check_outlined, 'audit.view'),
      const _AdminSection(
        'Team',
        Icons.admin_panel_settings_outlined,
        'roles.view',
      ),
    ];
    return candidates.where((section) {
      if (section.permission == '*') return true;
      if (section.permission == 'users.view' &&
          widget.access.hasPermission('users.suspend')) {
        return true;
      }
      return widget.access.hasPermission(section.permission);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (_index >= sections.length) _index = 0;
    final selected = sections[_index];
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.pondBlue,
                  child: Icon(Icons.admin_panel_settings, color: Colors.white),
                ),
                title: const Text(
                  'Tkoi Admin',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  widget.access.role?.replaceAll('_', ' ') ?? 'admin',
                ),
              ),
              const Divider(),
              for (var index = 0; index < sections.length; index++)
                ListTile(
                  selected: index == _index,
                  leading: Icon(sections[index].icon),
                  title: Text(sections[index].label),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _index = index);
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Marketplace view'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MainShell(access: widget.access),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: Text(_signingOut ? 'Signing out...' : 'Sign out'),
                enabled: !_signingOut,
                onTap: _signingOut
                    ? null
                    : () {
                        Navigator.pop(context);
                        _signOut();
                      },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: Text('Admin: ${selected.label}'),
        actions: [
          IconButton(
            tooltip: 'Open marketplace view',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MainShell(access: widget.access),
              ),
            ),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: selected.label == 'Dashboard'
          ? AdminDashboardScreen(access: widget.access)
          : selected.label == 'Team'
          ? const AdminTeamScreen()
          : selected.label == 'Users'
          ? const AdminUsersScreen()
          : selected.label == 'Support'
          ? AdminTicketsScreen(access: widget.access)
          : selected.label == 'Reports'
          ? AdminReportsScreen(access: widget.access)
          : selected.label == 'Content'
          ? const AdminContentScreen()
          : selected.label == 'Orders'
          ? const AdminOrdersScreen()
          : selected.label == 'Finance'
          ? AdminFinanceScreen(access: widget.access)
          : selected.label == 'Audit'
          ? const AdminAuditScreen()
          : _AdminSectionPlaceholder(
              section: selected,
              role: widget.access.role,
            ),
    );
  }
}

class _AdminSectionPlaceholder extends StatelessWidget {
  final _AdminSection section;
  final String? role;

  const _AdminSectionPlaceholder({required this.section, required this.role});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              gradient: AppColors.waterGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(section.icon, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 18),
          Text(
            section.label,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Signed in as ${role?.replaceAll('_', ' ') ?? 'admin'}.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
