import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../models/support_ticket.dart';
import '../../services/admin_support_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/safe_network_image.dart';

class AdminTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final AdminAccessContext access;

  const AdminTicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.access,
  });

  @override
  State<AdminTicketDetailScreen> createState() =>
      _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen> {
  late Future<AdminTicketDetail> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminSupportService().getTicket(widget.ticketId);
  }

  void _refresh() => setState(_load);

  Future<String?> _askText(String title, {String hint = '', int min = 10}) =>
      showDialog<String>(
        context: context,
        builder: (_) =>
            _AdminTextDialog(title: title, hint: hint, minLength: min),
      );

  Future<void> _reply(
    AdminTicketDetail ticket, {
    required bool internal,
  }) async {
    final input = await showDialog<_TicketReplyInput>(
      context: context,
      builder: (_) => _TicketReplyDialog(internal: internal),
    );
    if (!mounted || input == null) return;
    try {
      await AdminSupportService().reply(
        ticketId: ticket.id,
        body: input.body,
        internal: internal,
        reason: input.auditReason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              internal ? 'Internal note added.' : 'Reply sent to the user.',
            ),
          ),
        );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _changeState(AdminTicketDetail ticket) async {
    var status = ticket.status;
    var priority = ticket.priority;
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update ticket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final value in [
                    'open',
                    'in_progress',
                    'waiting_user',
                    'resolved',
                    'closed',
                  ])
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.replaceAll('_', ' ')),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => status = value ?? status),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final value in ['low', 'normal', 'high', 'urgent'])
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) =>
                    setDialogState(() => priority = value ?? priority),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'status': status,
                'priority': priority,
              }),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final reason = await _askText('Reason for this change');
    if (!mounted || reason == null) return;
    try {
      await AdminSupportService().updateTicket(
        ticketId: ticket.id,
        status: selected['status']!,
        priority: selected['priority']!,
        assignedTo: ticket.assignedTo,
        reason: reason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Ticket updated to ${selected['status']!.replaceAll('_', ' ')} with ${selected['priority']} priority.',
            ),
          ),
        );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  Future<void> _viewConversation(AdminTicketDetail ticket) async {
    final reason = await _askText(
      'Privacy access reason',
      hint: 'Explain why this ticket requires viewing the linked conversation.',
    );
    if (!mounted || reason == null) return;
    try {
      final messages = await AdminSupportService().viewTicketConversation(
        ticketId: ticket.id,
        reason: reason,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => _AdminConversationView(messages: messages),
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
    appBar: AppBar(title: const Text('Support ticket')),
    body: FutureBuilder<AdminTicketDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, onRetry: _refresh);
        }
        final ticket = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text('${ticket.userName} | @${ticket.username}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      children: [
                        Chip(label: Text(ticket.category)),
                        Chip(label: Text(ticket.status.replaceAll('_', ' '))),
                        Chip(label: Text('${ticket.priority} priority')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (widget.access.hasPermission('chat.view_via_ticket'))
              Card(
                color: AppColors.cream,
                child: ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.koiOrange,
                  ),
                  title: const Text('View case-linked conversation'),
                  subtitle: const Text(
                    'Private access requires a reason and is always audited.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _viewConversation(ticket),
                ),
              ),
            const SizedBox(height: 10),
            for (final message in ticket.messages)
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: message.isInternalNote
                      ? AppColors.cream
                      : Colors.white,
                  border: Border.all(
                    color: message.isInternalNote
                        ? AppColors.gold
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SafeNetworkImage(
                          url: message.senderAvatar,
                          width: 28,
                          height: 28,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.senderName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (message.isInternalNote)
                          const Chip(label: Text('Internal')),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(message.body),
                  ],
                ),
              ),
            if (widget.access.hasPermission('tickets.manage')) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _reply(ticket, internal: false),
                icon: const Icon(Icons.reply),
                label: const Text('Reply'),
              ),
              OutlinedButton.icon(
                onPressed: () => _reply(ticket, internal: true),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Add internal note'),
              ),
              TextButton.icon(
                onPressed: () => _changeState(ticket),
                icon: const Icon(Icons.tune),
                label: const Text('Change status or priority'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _TicketReplyInput {
  final String body;
  final String auditReason;

  const _TicketReplyInput({required this.body, required this.auditReason});
}

class _TicketReplyDialog extends StatefulWidget {
  final bool internal;

  const _TicketReplyDialog({required this.internal});

  @override
  State<_TicketReplyDialog> createState() => _TicketReplyDialogState();
}

class _TicketReplyDialogState extends State<_TicketReplyDialog> {
  final _body = TextEditingController();
  final _reason = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _body.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _validate() {
    final canSubmit =
        _body.text.trim().isNotEmpty && _reason.text.trim().length >= 10;
    if (canSubmit != _canSubmit) setState(() => _canSubmit = canSubmit);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.internal ? 'Add internal note' : 'Reply to user'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _body,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            onChanged: (_) => _validate(),
            decoration: InputDecoration(
              labelText: widget.internal
                  ? 'Internal note'
                  : 'Message to the user',
              helperText: widget.internal
                  ? 'Only admins can see this note.'
                  : null,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            onChanged: (_) => _validate(),
            decoration: const InputDecoration(
              labelText: 'Audit reason',
              helperText: 'Required, at least 10 characters.',
              alignLabelWithHint: true,
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
        onPressed: _canSubmit
            ? () => Navigator.pop(
                context,
                _TicketReplyInput(
                  body: _body.text.trim(),
                  auditReason: _reason.text.trim(),
                ),
              )
            : null,
        child: Text(widget.internal ? 'Add note' : 'Send reply'),
      ),
    ],
  );
}

class _AdminTextDialog extends StatefulWidget {
  final String title;
  final String hint;
  final int minLength;

  const _AdminTextDialog({
    required this.title,
    required this.hint,
    required this.minLength,
  });

  @override
  State<_AdminTextDialog> createState() => _AdminTextDialogState();
}

class _AdminTextDialogState extends State<_AdminTextDialog> {
  final _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: 2,
      maxLines: 5,
      maxLength: 1000,
      onChanged: (value) {
        final canSubmit = value.trim().length >= widget.minLength;
        if (canSubmit != _canSubmit) {
          setState(() => _canSubmit = canSubmit);
        }
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: 'At least ${widget.minLength} character(s).',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _canSubmit
            ? () => Navigator.pop(context, _controller.text.trim())
            : null,
        child: const Text('Continue'),
      ),
    ],
  );
}

class _AdminConversationView extends StatelessWidget {
  final List<AdminConversationMessage> messages;

  const _AdminConversationView({required this.messages});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Case-linked conversation')),
    body: Column(
      children: [
        const MaterialBanner(
          content: Text(
            'Privacy notice: access is limited to this support case and has been recorded in the audit log. Admins cannot send chat messages.',
          ),
          actions: [SizedBox.shrink()],
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final message = messages[index];
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: SafeNetworkImage(
                  url: message.senderAvatar,
                  width: 38,
                  height: 38,
                  borderRadius: BorderRadius.circular(19),
                ),
                title: Text(message.senderName),
                subtitle: Text(message.body),
              );
            },
          ),
        ),
      ],
    ),
  );
}
