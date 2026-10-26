import 'package:flutter/material.dart';

import '../../models/support_ticket.dart';
import '../../services/support_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import 'support_ticket_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  late Future<List<SupportTicket>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = SupportService().getMyTickets();
  }

  void _refresh() => setState(_load);

  Future<void> _create() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CreateSupportTicketScreen()),
    );
    if (!mounted) return;
    _refresh();
    if (id != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Support ticket submitted successfully.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Help & Support'),
      actions: [
        IconButton(
          tooltip: 'Refresh tickets',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 6),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      icon: const Icon(Icons.add_comment_outlined),
      label: const Text('New ticket'),
    ),
    body: FutureBuilder<List<SupportTicket>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TkoiLoadingView(
            message: 'Loading your support tickets...',
          );
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!, onRetry: _refresh);
        }
        final tickets = snapshot.data ?? const [];
        if (tickets.isEmpty) {
          return const EmptyState(
            icon: Icons.support_agent,
            title: 'No support tickets yet',
            message: 'Create a ticket when you need help with Tkoi.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return Card(
                child: ListTile(
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupportTicketScreen(
                          ticketId: ticket.id,
                          subject: ticket.subject,
                          status: ticket.status,
                        ),
                      ),
                    );
                    _refresh();
                  },
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.mist,
                    child: Icon(Icons.support_agent, color: AppColors.pondBlue),
                  ),
                  title: Text(ticket.subject),
                  subtitle: Text(
                    '${ticket.category.replaceAll('_', ' ')} · ${ticket.lastMessage}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Chip(
                    label: Text(ticket.status.replaceAll('_', ' ')),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class CreateSupportTicketScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSubject;
  final String? orderId;
  final String? productId;
  final String? shopId;
  final String? conversationId;
  final bool categoryLocked;

  const CreateSupportTicketScreen({
    super.key,
    this.initialCategory,
    this.initialSubject,
    this.orderId,
    this.productId,
    this.shopId,
    this.conversationId,
    this.categoryLocked = false,
  });

  @override
  State<CreateSupportTicketScreen> createState() =>
      _CreateSupportTicketScreenState();
}

class _CreateSupportTicketScreenState extends State<CreateSupportTicketScreen> {
  static const _categories = [
    'account',
    'order',
    'payment',
    'report',
    'appeal',
    'other',
  ];
  final _formKey = GlobalKey<FormState>();
  late String _category;
  late final TextEditingController _subject;
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? 'other';
    _subject = TextEditingController(text: widget.initialSubject);
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    var submitted = false;
    try {
      final id = await SupportService().createTicket(
        category: _category,
        subject: _subject.text,
        body: _body.text,
        orderId: widget.orderId,
        productId: widget.productId,
        shopId: widget.shopId,
        conversationId: widget.conversationId,
      );
      if (!mounted) return;
      submitted = true;
      Navigator.pop(context, id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted && !submitted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create support ticket')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in _categories)
                DropdownMenuItem(
                  value: category,
                  child: Text(category.replaceAll('_', ' ')),
                ),
            ],
            onChanged: widget.categoryLocked || _saving
                ? null
                : (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _subject,
            enabled: !_saving,
            maxLength: 120,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.length < 5) {
                return 'Enter a subject using at least 5 characters.';
              }
              if (text.contains(RegExp(r'[<>]'))) {
                return 'The subject cannot contain < or >.';
              }
              return null;
            },
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _body,
            enabled: !_saving,
            minLines: 6,
            maxLines: 10,
            maxLength: 4000,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.length < 10) {
                return 'Describe the issue using at least 10 characters.';
              }
              if (text.contains(RegExp(r'[<>]'))) {
                return 'The message cannot contain < or >.';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'How can we help?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Submitting...' : 'Submit ticket'),
          ),
        ],
      ),
    ),
  );
}
