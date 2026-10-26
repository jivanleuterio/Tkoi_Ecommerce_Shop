import 'package:flutter/material.dart';

import '../../models/moderation_content.dart';
import '../../services/admin_content_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/safe_network_image.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  final _search = TextEditingController();
  String _type = 'product';
  String? _status;
  late Future<List<ModerationContent>> _future;

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
    _future = AdminContentService().getContent(
      contentType: _type,
      status: _status,
      search: _search.text,
    );
  }

  void _refresh() => setState(_load);

  Future<void> _moderate(ModerationContent item, String status) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ContentModerationDialog(item: item, targetStatus: status),
    );
    if (!mounted || reason == null) return;
    try {
      await AdminContentService().setModeration(
        contentType: item.contentType,
        contentId: item.id,
        status: status,
        reason: reason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${item.contentType[0].toUpperCase()}${item.contentType.substring(1)} marked ${status.replaceAll('_', ' ')}.',
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _refresh(),
          decoration: const InputDecoration(
            hintText: 'Search moderated content',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'product', label: Text('Listings')),
                ButtonSegment(value: 'shop', label: Text('Shops')),
                ButtonSegment(value: 'review', label: Text('Reviews')),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (values) {
                _type = values.first;
                _refresh();
              },
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String?>(
              tooltip: 'Filter moderation status',
              onSelected: (value) {
                _status = value;
                _refresh();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: null, child: Text('All states')),
                PopupMenuItem(value: 'clear', child: Text('Clear')),
                PopupMenuItem(
                  value: 'under_review',
                  child: Text('Under review'),
                ),
                PopupMenuItem(value: 'removed', child: Text('Removed')),
              ],
              icon: const Icon(Icons.filter_list),
            ),
            Text(_status?.replaceAll('_', ' ') ?? 'All'),
            IconButton(
              tooltip: 'Refresh content',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: FutureBuilder<List<ModerationContent>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const TkoiLoadingView(message: 'Loading content...');
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: _refresh);
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.policy_outlined,
                title: 'No content found',
                message: 'Try another content type, status, or search.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SafeNetworkImage(
                            url: item.imageUrl,
                            width: 62,
                            height: 62,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.softGray,
                                  ),
                                ),
                                if (item.reason.isNotEmpty)
                                  Text(
                                    item.reason,
                                    style: const TextStyle(
                                      color: AppColors.vermilion,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 7,
                                  children: [
                                    Chip(
                                      label: Text(
                                        item.status.replaceAll('_', ' '),
                                      ),
                                    ),
                                    if (item.status != 'under_review')
                                      TextButton(
                                        onPressed: () =>
                                            _moderate(item, 'under_review'),
                                        child: const Text('Review'),
                                      ),
                                    if (item.status != 'removed')
                                      TextButton(
                                        onPressed: () =>
                                            _moderate(item, 'removed'),
                                        child: const Text('Remove'),
                                      ),
                                    if (item.status != 'clear')
                                      TextButton(
                                        onPressed: () =>
                                            _moderate(item, 'clear'),
                                        child: const Text('Restore'),
                                      ),
                                  ],
                                ),
                              ],
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
    ],
  );
}

class _ContentModerationDialog extends StatefulWidget {
  final ModerationContent item;
  final String targetStatus;

  const _ContentModerationDialog({
    required this.item,
    required this.targetStatus,
  });

  @override
  State<_ContentModerationDialog> createState() =>
      _ContentModerationDialogState();
}

class _ContentModerationDialogState extends State<_ContentModerationDialog> {
  final _reason = TextEditingController();
  bool _canConfirm = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetStatus.replaceAll('_', ' ');
    final destructive = widget.targetStatus == 'removed';
    return AlertDialog(
      title: Text(
        widget.targetStatus == 'clear'
            ? 'Restore ${widget.item.contentType}'
            : '${destructive ? 'Remove' : 'Review'} ${widget.item.contentType}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${widget.item.status.replaceAll('_', ' ')} -> $target',
            ),
            if (destructive) ...[
              const SizedBox(height: 8),
              const Text(
                'This content will no longer be visible to other users.',
                style: TextStyle(color: AppColors.vermilion),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              onChanged: (value) =>
                  setState(() => _canConfirm = value.trim().length >= 10),
              decoration: const InputDecoration(
                labelText: 'Reason (at least 10 characters)',
                helperText: 'Restricted owners can see this reason.',
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
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.vermilion)
              : null,
          onPressed: _canConfirm
              ? () => Navigator.pop(context, _reason.text.trim())
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
