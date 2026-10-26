import 'package:flutter/material.dart';

import '../../models/support_ticket.dart';
import '../../services/support_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';

class SupportTicketScreen extends StatefulWidget {
  final String ticketId;
  final String subject;
  final String? status;

  const SupportTicketScreen({
    super.key,
    required this.ticketId,
    required this.subject,
    this.status,
  });

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _message = TextEditingController();
  late Future<List<SupportMessage>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = SupportService().getMessages(widget.ticketId);
  }

  void _refresh() => setState(_load);

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await SupportService().sendMessage(widget.ticketId, _message.text);
      _message.clear();
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = widget.status == 'resolved' || widget.status == 'closed';
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<SupportMessage>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error!, onRetry: _refresh);
                }
                final messages = snapshot.data ?? const [];
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return Align(
                        alignment: message.isAgent
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 330),
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: message.isAgent
                                ? Colors.white
                                : AppColors.koiOrange,
                            border: message.isAgent
                                ? Border.all(color: AppColors.border)
                                : null,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.isAgent ? message.senderName : 'You',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: message.isAgent
                                      ? AppColors.pondBlue
                                      : Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                message.body,
                                style: TextStyle(
                                  color: message.isAgent
                                      ? AppColors.sumi
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: closed
                  ? const Text('This support ticket is closed.')
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _message,
                            enabled: !_sending,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 4000,
                            buildCounter: (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                            decoration: const InputDecoration(
                              hintText: 'Reply to support...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
