import 'package:flutter/material.dart';

import '../services/support_service.dart';
import '../utils/formatters.dart';

class ReportButton extends StatelessWidget {
  final String targetType;
  final String targetId;
  final String label;
  final bool compact;

  const ReportButton({
    super.key,
    required this.targetType,
    required this.targetId,
    this.label = 'Report',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    void open() => showDialog<void>(
      context: context,
      builder: (_) => _ReportDialog(targetType: targetType, targetId: targetId),
    );
    if (compact) {
      return IconButton(
        tooltip: label,
        visualDensity: VisualDensity.compact,
        onPressed: open,
        icon: const Icon(Icons.flag_outlined, size: 19),
      );
    }
    return TextButton.icon(
      onPressed: open,
      icon: const Icon(Icons.flag_outlined),
      label: Text(label),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  final String targetType;
  final String targetId;

  const _ReportDialog({required this.targetType, required this.targetId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const _reasons = [
    'Misleading information',
    'Fraud or scam',
    'Abusive content',
    'Unsafe animal welfare',
    'Spam',
    'Other',
  ];
  final _details = TextEditingController();
  String _reason = _reasons.first;
  bool _saving = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_details.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Describe the issue in at least 10 characters.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupportService().createReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reasonCategory: _reason,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted for review.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Report ${widget.targetType}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final reason in _reasons)
                DropdownMenuItem(value: reason, child: Text(reason)),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _reason = value ?? _reason),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            enabled: !_saving,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: Text(_saving ? 'Submitting...' : 'Submit report'),
      ),
    ],
  );
}
