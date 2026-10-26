import 'package:flutter/material.dart';

import '../../models/admin_access.dart';
import '../../models/admin_operations.dart';
import '../../models/seller_wallet.dart';
import '../../services/admin_operations_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

class AdminFinanceScreen extends StatefulWidget {
  final AdminAccessContext access;
  const AdminFinanceScreen({super.key, required this.access});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  late String _section;

  List<String> get _sections => [
    if (widget.access.hasPermission('withdrawals.view')) 'Withdrawals',
    if (widget.access.hasPermission('returns.decide')) 'Returns',
    if (widget.access.hasPermission('wallet.view')) 'Wallets',
    if (widget.access.hasPermission('settings.view')) 'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _section = _sections.firstOrNull ?? 'Withdrawals';
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (!sections.contains(_section) && sections.isNotEmpty) {
      _section = sections.first;
    }
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(10),
          child: SegmentedButton<String>(
            segments: [
              for (final section in sections)
                ButtonSegment(value: section, label: Text(section)),
            ],
            selected: {_section},
            showSelectedIcon: false,
            onSelectionChanged: (values) =>
                setState(() => _section = values.first),
          ),
        ),
        Expanded(
          child: switch (_section) {
            'Returns' => _ReturnsQueue(access: widget.access),
            'Wallets' => const _WalletsView(),
            'Settings' => _SettingsView(access: widget.access),
            _ => _WithdrawalsQueue(access: widget.access),
          },
        ),
      ],
    );
  }
}

class _WithdrawalsQueue extends StatefulWidget {
  final AdminAccessContext access;
  const _WithdrawalsQueue({required this.access});

  @override
  State<_WithdrawalsQueue> createState() => _WithdrawalsQueueState();
}

class _WithdrawalsQueueState extends State<_WithdrawalsQueue> {
  late Future<List<AdminWithdrawal>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminOperationsService().getWithdrawals();
  }

  void _refresh() => setState(_load);

  Future<String?> _prompt(
    String title,
    String label, {
    bool exactPaid = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _AdminPromptDialog(title: title, label: label, exactPaid: exactPaid),
  );

  Future<void> _reveal(AdminWithdrawal item) async {
    final reason = await _prompt(
      'Reveal payout account',
      'Required audit reason',
    );
    if (!mounted || reason == null) return;
    try {
      final data = await AdminOperationsService().revealWithdrawal(
        item.id,
        reason,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Payout account'),
          content: SelectableText(
            '${data['method']}\n${data['account_name']}\n${data['account_number']}\n${data['bank_name'] ?? ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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

  Future<void> _process(AdminWithdrawal item, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${action[0].toUpperCase()}${action.substring(1)} withdrawal?',
        ),
        content: Text(
          '${item.shopName}\n'
          'Seller: ${item.sellerName}\n'
          'Amount: ${pesoCentavos(item.amountCentavos)}\n'
          'Status: ${item.status} -> $action'
          '${item.isDemo ? '\n\nDemo request: no real money will be sent.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: action == 'reject'
                ? FilledButton.styleFrom(backgroundColor: AppColors.vermilion)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (action == 'paid') {
      final typed = await _prompt(
        'Confirm paid withdrawal',
        'Type PAID to confirm',
        exactPaid: true,
      );
      if (!mounted || typed == null) return;
    }
    final note = await _prompt(
      '${action[0].toUpperCase()}${action.substring(1)} withdrawal',
      'Admin note (at least 10 characters)',
    );
    if (!mounted || note == null) return;
    String? reference;
    if (action == 'paid') {
      reference = await _prompt('Payment reference', 'Reference number');
      if (!mounted || reference == null) return;
    }
    final reason = await _prompt(
      'Audit reason',
      'Why is this action being taken?',
    );
    if (!mounted || reason == null) return;
    try {
      await AdminOperationsService().processWithdrawal(
        id: item.id,
        action: action,
        note: note,
        reference: reference,
        reason: reason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Withdrawal marked $action.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AdminWithdrawal>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const TkoiLoadingView(message: 'Loading withdrawals...');
      }
      if (snapshot.hasError) {
        return ErrorView(error: snapshot.error!, onRetry: _refresh);
      }
      final items = snapshot.data ?? const [];
      if (items.isEmpty) {
        return const EmptyState(
          icon: Icons.payments_outlined,
          title: 'No withdrawals',
          message: 'Withdrawal requests will appear here.',
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.shopName} | ${pesoCentavos(item.amountCentavos)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(label: Text(item.status)),
                      ],
                    ),
                    Text(
                      '${item.sellerName} | ${item.payoutMethod} ${item.maskedAccount}',
                    ),
                    if (item.isDemo)
                      const Text(
                        'Demo only - no real money sent',
                        style: TextStyle(color: AppColors.koiOrange),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.access.hasPermission('withdrawals.reveal'))
                          TextButton(
                            onPressed: () => _reveal(item),
                            child: const Text('Reveal account'),
                          ),
                        if (widget.access.hasPermission('withdrawals.manage') &&
                            item.status == 'pending') ...[
                          TextButton(
                            onPressed: () => _process(item, 'reject'),
                            child: const Text('Reject'),
                          ),
                          FilledButton(
                            onPressed: () => _process(item, 'approve'),
                            child: const Text('Approve'),
                          ),
                        ],
                        if (widget.access.hasPermission('withdrawals.manage') &&
                            item.status == 'approved')
                          FilledButton(
                            onPressed: () => _process(item, 'paid'),
                            child: const Text('Mark paid'),
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
  );
}

class _ReturnsQueue extends StatefulWidget {
  final AdminAccessContext access;
  const _ReturnsQueue({required this.access});
  @override
  State<_ReturnsQueue> createState() => _ReturnsQueueState();
}

class _ReturnsQueueState extends State<_ReturnsQueue> {
  late Future<List<AdminReturnRequest>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminOperationsService().getReturns();
  }

  void _refresh() => setState(_load);

  Future<void> _decide(AdminReturnRequest item, String status) async {
    final input = await showDialog<_ReturnDecisionInput>(
      context: context,
      builder: (_) => _ReturnDecisionDialog(item: item, targetStatus: status),
    );
    if (!mounted || input == null) return;
    try {
      await AdminOperationsService().decideReturn(
        id: item.id,
        status: status,
        note: input.note,
        reason: input.reason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Return marked $status.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AdminReturnRequest>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const TkoiLoadingView(message: 'Loading returns...');
      }
      if (snapshot.hasError) {
        return ErrorView(error: snapshot.error!, onRetry: _refresh);
      }
      final items = snapshot.data ?? const [];
      if (items.isEmpty) {
        return const EmptyState(
          icon: Icons.assignment_return_outlined,
          title: 'No returns',
          message: 'Return requests will appear here.',
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.reason,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(label: Text(item.status)),
                      ],
                    ),
                    Text(
                      '${item.buyerName} | ${item.shopName} | ${pesoCentavos(item.orderTotalCentavos)}',
                    ),
                    const SizedBox(height: 6),
                    Text(item.details),
                    const SizedBox(height: 6),
                    const Text(
                      'Refund to buyer must be completed manually.',
                      style: TextStyle(
                        color: AppColors.vermilion,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!const {
                      'resolved',
                      'rejected',
                      'cancelled',
                    }.contains(item.status))
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _decide(item, 'rejected'),
                            child: const Text('Reject'),
                          ),
                          TextButton(
                            onPressed: () => _decide(item, 'approved'),
                            child: const Text('Approve'),
                          ),
                          FilledButton(
                            onPressed: () => _decide(item, 'resolved'),
                            child: const Text('Force resolve'),
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
  );
}

class _WalletsView extends StatefulWidget {
  const _WalletsView();
  @override
  State<_WalletsView> createState() => _WalletsViewState();
}

class _WalletsViewState extends State<_WalletsView> {
  late Future<List<AdminWalletSummary>> _future;
  @override
  void initState() {
    super.initState();
    _future = AdminOperationsService().getWallets();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AdminWalletSummary>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const TkoiLoadingView(message: 'Loading seller wallets...');
      }
      if (snapshot.hasError) {
        return ErrorView(
          error: snapshot.error!,
          onRetry: () =>
              setState(() => _future = AdminOperationsService().getWallets()),
        );
      }
      final wallets = snapshot.data ?? const [];
      if (wallets.isEmpty) {
        return const EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No wallets',
          message: 'Seller wallet summaries will appear here.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: wallets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final wallet = wallets[index];
          return Card(
            child: ListTile(
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => _WalletLedgerScreen(wallet: wallet),
                ),
              ),
              title: Text(wallet.shopName),
              subtitle: Text(
                '${wallet.sellerName}\nPending ${pesoCentavos(wallet.pendingCentavos)} | Earned ${pesoCentavos(wallet.totalEarnedCentavos)}',
              ),
              isThreeLine: true,
              trailing: Text(
                pesoCentavos(wallet.availableCentavos),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: wallet.availableCentavos < 0
                      ? AppColors.vermilion
                      : AppColors.success,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _WalletLedgerScreen extends StatelessWidget {
  final AdminWalletSummary wallet;
  const _WalletLedgerScreen({required this.wallet});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(wallet.shopName)),
    body: FutureBuilder<List<SellerWalletTransaction>>(
      future: AdminOperationsService().getLedger(wallet.shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error!);
        }
        final rows = snapshot.data ?? const [];
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, index) {
            final row = rows[index];
            return ListTile(
              title: Text(row.title),
              subtitle: Text('${row.status} | ${row.note}'),
              trailing: Text(pesoCentavos(row.amountCentavos)),
            );
          },
        );
      },
    ),
  );
}

class _SettingsView extends StatefulWidget {
  final AdminAccessContext access;
  const _SettingsView({required this.access});
  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  late Future<AdminMarketplaceSettings> _future;
  @override
  void initState() {
    super.initState();
    _future = AdminOperationsService().getSettings();
  }

  void _reload() =>
      setState(() => _future = AdminOperationsService().getSettings());
  Future<void> _edit(AdminMarketplaceSettings settings) async {
    final input = await showDialog<_SettingsInput>(
      context: context,
      builder: (_) => _SettingsDialog(settings: settings),
    );
    if (!mounted || input == null) return;
    try {
      await AdminOperationsService().updateSettings(
        fee: input.fee,
        minimum: input.minimum,
        days: input.days,
        demoMode: input.demoMode,
        reason: input.reason,
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Marketplace settings updated.')),
        );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminMarketplaceSettings>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const TkoiLoadingView(message: 'Loading settings...');
      }
      if (snapshot.hasError) {
        return ErrorView(error: snapshot.error!, onRetry: _reload);
      }
      final settings = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Platform commission'),
                  trailing: Text('${settings.platformFeePercent}%'),
                ),
                ListTile(
                  title: const Text('Minimum withdrawal'),
                  trailing: Text('PHP ${settings.minimumWithdrawal}'),
                ),
                ListTile(
                  title: const Text('Escrow auto-release'),
                  trailing: Text('${settings.autoReleaseDays} days'),
                ),
                ListTile(
                  title: const Text('Demo mode'),
                  trailing: Icon(
                    settings.demoMode ? Icons.check_circle : Icons.cancel,
                    color: settings.demoMode
                        ? AppColors.success
                        : AppColors.vermilion,
                  ),
                ),
              ],
            ),
          ),
          if (widget.access.hasPermission('settings.edit'))
            FilledButton.icon(
              onPressed: () => _edit(settings),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit settings'),
            ),
        ],
      );
    },
  );
}

class _AdminPromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final bool exactPaid;

  const _AdminPromptDialog({
    required this.title,
    required this.label,
    required this.exactPaid,
  });

  @override
  State<_AdminPromptDialog> createState() => _AdminPromptDialogState();
}

class _AdminPromptDialogState extends State<_AdminPromptDialog> {
  final _controller = TextEditingController();
  bool _canContinue = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    final text = value.trim();
    final canContinue = widget.exactPaid ? text == 'PAID' : text.length >= 10;
    if (canContinue != _canContinue) {
      setState(() => _canContinue = canContinue);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: widget.exactPaid ? 4 : 500,
      minLines: widget.exactPaid ? 1 : 2,
      maxLines: widget.exactPaid ? 1 : 4,
      onChanged: _validate,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.exactPaid
            ? 'Enter PAID exactly.'
            : 'At least 10 characters.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _canContinue
            ? () => Navigator.pop(context, _controller.text.trim())
            : null,
        child: const Text('Continue'),
      ),
    ],
  );
}

class _ReturnDecisionInput {
  final String note;
  final String reason;

  const _ReturnDecisionInput({required this.note, required this.reason});
}

class _ReturnDecisionDialog extends StatefulWidget {
  final AdminReturnRequest item;
  final String targetStatus;

  const _ReturnDecisionDialog({required this.item, required this.targetStatus});

  @override
  State<_ReturnDecisionDialog> createState() => _ReturnDecisionDialogState();
}

class _ReturnDecisionDialogState extends State<_ReturnDecisionDialog> {
  final _note = TextEditingController();
  final _reason = TextEditingController();
  bool _canConfirm = false;

  @override
  void dispose() {
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _validate() {
    final canConfirm =
        _note.text.trim().length >= 10 && _reason.text.trim().length >= 10;
    if (canConfirm != _canConfirm) {
      setState(() => _canConfirm = canConfirm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destructive = const {
      'rejected',
      'resolved',
    }.contains(widget.targetStatus);
    return AlertDialog(
      title: Text('Set return to ${widget.targetStatus}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.item.buyerName} | ${widget.item.shopName}\n'
              '${pesoCentavos(widget.item.orderTotalCentavos)} | '
              '${widget.item.status} -> ${widget.targetStatus}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Buyer refunds are still manual. This action only updates the return and seller ledger.',
              style: TextStyle(color: AppColors.vermilion),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (_) => _validate(),
              decoration: const InputDecoration(
                labelText: 'Decision note',
                helperText: 'At least 10 characters.',
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
              ? () => Navigator.pop(
                  context,
                  _ReturnDecisionInput(
                    note: _note.text.trim(),
                    reason: _reason.text.trim(),
                  ),
                )
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _SettingsInput {
  final String fee;
  final String minimum;
  final int days;
  final bool demoMode;
  final String reason;

  const _SettingsInput({
    required this.fee,
    required this.minimum,
    required this.days,
    required this.demoMode,
    required this.reason,
  });
}

class _SettingsDialog extends StatefulWidget {
  final AdminMarketplaceSettings settings;

  const _SettingsDialog({required this.settings});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _fee;
  late final TextEditingController _minimum;
  late final TextEditingController _days;
  final _reason = TextEditingController();
  late bool _demoMode;
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _fee = TextEditingController(text: widget.settings.platformFeePercent);
    _minimum = TextEditingController(text: widget.settings.minimumWithdrawal);
    _days = TextEditingController(text: '${widget.settings.autoReleaseDays}');
    _demoMode = widget.settings.demoMode;
  }

  @override
  void dispose() {
    _fee.dispose();
    _minimum.dispose();
    _days.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _validate() {
    final fee = num.tryParse(_fee.text);
    final minimum = num.tryParse(_minimum.text);
    final days = int.tryParse(_days.text);
    final canSave =
        fee != null &&
        fee >= 0 &&
        fee <= 30 &&
        minimum != null &&
        minimum >= 1 &&
        minimum <= 100000 &&
        days != null &&
        days >= 1 &&
        days <= 90 &&
        _reason.text.trim().length >= 10;
    if (canSave != _canSave) setState(() => _canSave = canSave);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Marketplace settings'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: ${widget.settings.platformFeePercent}% fee | '
            'PHP ${widget.settings.minimumWithdrawal} minimum | '
            '${widget.settings.autoReleaseDays} release days',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _validate(),
            decoration: const InputDecoration(
              labelText: 'Platform fee %',
              helperText: '0 to 30 percent.',
            ),
          ),
          TextField(
            controller: _minimum,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _validate(),
            decoration: const InputDecoration(
              labelText: 'Minimum withdrawal PHP',
              helperText: 'PHP 1 to PHP 100,000.',
            ),
          ),
          TextField(
            controller: _days,
            keyboardType: TextInputType.number,
            onChanged: (_) => _validate(),
            decoration: const InputDecoration(
              labelText: 'Auto-release days',
              helperText: '1 to 90 days.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _demoMode,
            onChanged: (value) {
              setState(() => _demoMode = value);
              _validate();
            },
            title: const Text('Demo mode'),
          ),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            onChanged: (_) => _validate(),
            decoration: const InputDecoration(
              labelText: 'Audit reason',
              helperText: 'At least 10 characters.',
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
        onPressed: _canSave
            ? () => Navigator.pop(
                context,
                _SettingsInput(
                  fee: _fee.text.trim(),
                  minimum: _minimum.text.trim(),
                  days: int.parse(_days.text),
                  demoMode: _demoMode,
                  reason: _reason.text.trim(),
                ),
              )
            : null,
        child: const Text('Save changes'),
      ),
    ],
  );
}
