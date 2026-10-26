import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../models/support_ticket.dart';
import '../../services/admin_support_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';
import 'admin_ticket_detail_screen.dart';

class AdminTicketsScreen extends StatefulWidget {
  final AdminAccessContext access;

  const AdminTicketsScreen({super.key, required this.access});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  String? _status;
  bool _mine = false;
  late Future<List<AdminTicketSummary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminSupportService().getTickets(
      status: _status,
      assignedToMe: _mine,
    );
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Row(
          children: [
            for (final status in <String?>[
              null,
              'open',
              'in_progress',
              'waiting_user',
              'resolved',
              'closed',
            ]) ...[
              ChoiceChip(
                label: Text(status?.replaceAll('_', ' ') ?? 'All'),
                selected: _status == status,
                onSelected: (_) {
                  _status = status;
                  _refresh();
                },
              ),
              const SizedBox(width: 7),
            ],
            FilterChip(
              label: const Text('Assigned to me'),
              selected: _mine,
              onSelected: (value) {
                _mine = value;
                _refresh();
              },
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<AdminTicketSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TkoiLoadingView(message: 'Loading support queue...');
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _refresh);
            }
            final tickets = snapshot.data ?? const [];
            if (tickets.isEmpty) {
              return const EmptyState(
                icon: Icons.support_agent,
                title: 'No tickets here',
                message: 'The selected queue is empty.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 22),
                itemCount: tickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = tickets[index];
                  return Card(
                    child: ListTile(
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminTicketDetailScreen(
                              ticketId: entry.ticket.id,
                              access: widget.access,
                            ),
                          ),
                        );
                        _refresh();
                      },
                      leading: SafeNetworkImage(
                        url: entry.userAvatar,
                        width: 46,
                        height: 46,
                        borderRadius: BorderRadius.circular(23),
                      ),
                      title: Text(entry.ticket.subject),
                      subtitle: Text(
                        '${entry.userName} | ${entry.ticket.category}\n'
                        '${entry.messageCount} messages | ${entry.ticket.priority} priority',
                      ),
                      isThreeLine: true,
                      trailing: Chip(
                        label: Text(entry.ticket.status.replaceAll('_', ' ')),
                      ),
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
