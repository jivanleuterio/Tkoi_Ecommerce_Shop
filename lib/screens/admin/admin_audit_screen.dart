import 'package:flutter/material.dart';

import '../../models/admin_operations.dart';
import '../../services/admin_operations_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  final _search = TextEditingController();
  late Future<List<AdminAuditEntry>> _future;

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
    _future = AdminOperationsService().getAudit(action: _search.text);
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: TextField(
          controller: _search,
          onSubmitted: (_) => _refresh(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search audit action',
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<AdminAuditEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TkoiLoadingView(message: 'Loading audit log...');
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _refresh);
            }
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) {
              return const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No audit entries',
                message:
                    'Admin state changes and sensitive reveals appear here.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.history)),
                      title: Text(row.action.replaceAll('_', ' ')),
                      subtitle: Text(
                        '${row.adminName} | ${row.targetType}\n${row.reason}',
                      ),
                      isThreeLine: true,
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
