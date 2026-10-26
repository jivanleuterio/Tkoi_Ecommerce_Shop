import 'package:flutter/material.dart';

import '../../models/admin_user.dart';
import '../../services/admin_moderation_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<AdminUserDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = AdminModerationService().getUser(widget.userId);
  }

  Future<String?> _askReason(
    String title, {
    String? summary,
    bool destructive = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _ReasonDialog(title: title, summary: summary, destructive: destructive),
  );

  Future<void> _setStatus(String status, AdminUserDetail user) async {
    final actionSummary = switch (status) {
      'suspended' =>
        '${user.fullName} will be unable to use restricted Tkoi features for 7 days.',
      'banned' =>
        '${user.fullName} will lose marketplace access until an admin reactivates the account.',
      _ => '${user.fullName} will regain normal marketplace access.',
    };
    final reason = await _askReason(
      '${status == 'active' ? 'Reactivate' : status} account',
      summary: actionSummary,
      destructive: status != 'active',
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      final until = status == 'suspended'
          ? DateTime.now().add(const Duration(days: 7))
          : null;
      final result = await AdminModerationService().setStatus(
        userId: widget.userId,
        status: status,
        restrictedUntil: until,
        publicReason: reason,
        internalReason: reason,
        auditReason: reason,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.authWarning ?? 'Account status changed to $status.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reveal() async {
    final reason = await _askReason('Reveal contact information');
    if (reason == null) return;
    try {
      final contact = await AdminModerationService().revealContact(
        userId: widget.userId,
        reason: reason,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Audited contact reveal'),
          content: Text('${contact['email']}\n${contact['phone']}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account details')),
    body: FutureBuilder<AdminUserDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TkoiLoadingView(message: 'Loading account...');
        }
        if (snapshot.hasError) {
          return ErrorView(
            error: snapshot.error!,
            onRetry: () => setState(_reload),
          );
        }
        final user = snapshot.data!;
        final shop = user.shop;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text('@${user.username}'),
                    const SizedBox(height: 12),
                    Text('Email: ${user.maskedEmail}'),
                    Text('Phone: ${user.maskedPhone}'),
                    Text('Status: ${user.status}'),
                    Text('Orders: ${user.orderCount}'),
                    if (shop != null)
                      Text('Shop: ${shop['name']} | ${shop['location']}'),
                    if (user.reasonPublic?.isNotEmpty == true)
                      Text('Public reason: ${user.reasonPublic}'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: user.role == null ? _reveal : null,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Reveal email and phone'),
                    ),
                  ],
                ),
              ),
            ),
            if (user.role != null)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Protected admin account'),
                  subtitle: Text(
                    'Admins cannot moderate themselves or other admins.',
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (user.status == 'active')
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _setStatus('suspended', user),
                      child: const Text('Suspend 7 days'),
                    ),
                  if (user.status != 'banned')
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _setStatus('banned', user),
                      child: const Text('Ban'),
                    ),
                  if (user.status != 'active')
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _setStatus('active', user),
                      child: const Text('Reactivate'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Status history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (user.history.isEmpty)
              const Text('No moderation history.')
            else
              for (final item in user.history)
                Card(
                  child: ListTile(
                    title: Text(item['status'] as String? ?? 'active'),
                    subtitle: Text(item['reason_public'] as String? ?? ''),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String? summary;
  final bool destructive;

  const _ReasonDialog({
    required this.title,
    this.summary,
    this.destructive = false,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.summary != null) ...[
            Text(widget.summary!),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            onChanged: (value) {
              final canConfirm = value.trim().length >= 10;
              if (canConfirm != _canConfirm) {
                setState(() => _canConfirm = canConfirm);
              }
            },
            decoration: const InputDecoration(
              labelText: 'Reason (at least 10 characters)',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: widget.destructive
            ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
            : null,
        onPressed: _canConfirm
            ? () => Navigator.pop(context, _controller.text.trim())
            : null,
        child: const Text('Confirm'),
      ),
    ],
  );
}
