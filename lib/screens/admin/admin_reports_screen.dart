import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../models/support_ticket.dart';
import '../../services/admin_support_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

class AdminReportsScreen extends StatefulWidget {
  final AdminAccessContext access;

  const AdminReportsScreen({super.key, required this.access});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String? _status;
  late Future<List<UserReport>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminSupportService().getReports(status: _status);
  }

  void _refresh() => setState(_load);

  void _selectStatus(String? status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _load();
    });
  }

  Future<void> _resolve(UserReport report, String status) async {
    final input = await showDialog<_ReportResolutionInput>(
      context: context,
      builder: (_) => _ReportResolutionDialog(report: report, status: status),
    );
    if (!mounted || input == null) return;
    try {
      await AdminSupportService().resolveReport(
        reportId: report.id,
        status: status,
        resolution: input.resolution,
        reason: input.auditReason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Report marked as $status.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter reports by status',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh reports',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final status in <String?>[
                  null,
                  'open',
                  'reviewing',
                  'actioned',
                  'dismissed',
                ])
                  ChoiceChip(
                    label: Text(status ?? 'All'),
                    selected: _status == status,
                    onSelected: (_) => _selectStatus(status),
                  ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<UserReport>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TkoiLoadingView(message: 'Loading reports...');
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _refresh);
            }
            final reports = snapshot.data ?? const [];
            if (reports.isEmpty) {
              return const EmptyState(
                icon: Icons.flag_outlined,
                title: 'No reports here',
                message: 'The selected report queue is empty.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                itemCount: reports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${report.targetType} report',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              Chip(label: Text(report.status)),
                            ],
                          ),
                          Text(
                            report.reasonCategory,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          Text(report.details),
                          const SizedBox(height: 6),
                          Text(
                            'Submitted by ${report.reporterName}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (widget.access.hasPermission('reports.manage') &&
                              report.status != 'actioned' &&
                              report.status != 'dismissed')
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _resolve(report, 'reviewing'),
                                  child: const Text('Reviewing'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _resolve(report, 'dismissed'),
                                  child: const Text('Dismiss'),
                                ),
                                FilledButton(
                                  onPressed: () => _resolve(report, 'actioned'),
                                  child: const Text('Action taken'),
                                ),
                              ],
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
    ],
  );
}

class _ReportResolutionInput {
  final String resolution;
  final String auditReason;

  const _ReportResolutionInput({
    required this.resolution,
    required this.auditReason,
  });
}

class _ReportResolutionDialog extends StatefulWidget {
  final UserReport report;
  final String status;

  const _ReportResolutionDialog({required this.report, required this.status});

  @override
  State<_ReportResolutionDialog> createState() =>
      _ReportResolutionDialogState();
}

class _ReportResolutionDialogState extends State<_ReportResolutionDialog> {
  final _resolution = TextEditingController();
  final _reason = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _resolution.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _validate() {
    final canSubmit =
        _resolution.text.trim().length >= 10 &&
        _reason.text.trim().length >= 10;
    if (canSubmit != _canSubmit) setState(() => _canSubmit = canSubmit);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.status == 'dismissed'
          ? 'Dismiss report'
          : 'Mark report ${widget.status}',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${widget.report.targetType} | ${widget.report.reasonCategory}\n'
              '${widget.report.status} -> ${widget.status}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _resolution,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            onChanged: (_) => _validate(),
            decoration: const InputDecoration(
              labelText: 'Resolution note',
              helperText: 'At least 10 characters.',
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
              helperText: 'At least 10 characters.',
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
        style: widget.status == 'dismissed'
            ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
            : null,
        onPressed: _canSubmit
            ? () => Navigator.pop(
                context,
                _ReportResolutionInput(
                  resolution: _resolution.text.trim(),
                  auditReason: _reason.text.trim(),
                ),
              )
            : null,
        child: const Text('Confirm'),
      ),
    ],
  );
}
