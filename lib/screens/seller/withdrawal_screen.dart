import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/seller_payout.dart';
import '../../models/seller_wallet.dart';
import '../../models/shop.dart';
import '../../services/seller_payout_service.dart';
import '../../services/seller_wallet_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import 'payout_accounts_screen.dart';

class WithdrawalScreen extends StatefulWidget {
  final Shop shop;

  const WithdrawalScreen({super.key, required this.shop});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amount = TextEditingController();
  late Future<_WithdrawalData> _future;
  String? _accountId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _load() {
    _future =
        Future.wait([
          SellerWalletService().getSummary(widget.shop.id),
          SellerPayoutService().getAccounts(widget.shop.id),
          SellerPayoutService().getWithdrawals(widget.shop.id),
        ]).then(
          (values) => _WithdrawalData(
            summary: values[0] as SellerWalletSummary,
            accounts: values[1] as List<SellerPayoutAccount>,
            withdrawals: values[2] as List<SellerWithdrawal>,
          ),
        );
  }

  void _refresh() => setState(_load);

  Future<void> _manageAccounts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayoutAccountsScreen(shop: widget.shop),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _submit(_WithdrawalData data) async {
    final cents = centavosFromInput(_amount.text);
    if (cents == null) {
      _message('Enter a valid amount with up to two decimal places.');
      return;
    }
    final validation = validateWithdrawal(
      summary: data.summary,
      amountCentavos: cents,
      hasPendingRequest: data.withdrawals.any(
        (withdrawal) => withdrawal.status == 'pending',
      ),
    );
    if (validation != null) {
      _message(validation);
      return;
    }
    final account = data.accounts
        .where((item) => item.id == _accountId)
        .firstOrNull;
    if (account == null) {
      _message('Choose a payout account.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm demo withdrawal'),
        content: Text(
          '${pesoCentavos(cents)} will be deducted from your Tkoi balance and '
          'recorded as paid to ${account.methodLabel} ${account.maskedNumber}. '
          'This is a demo only—no real money will be transferred.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm demo withdrawal'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _submitting = true);
    try {
      await SellerPayoutService().requestDemoWithdrawal(
        shopId: widget.shop.id,
        amount: _amount.text.trim(),
        payoutAccountId: account.id,
      );
      _amount.clear();
      if (!mounted) return;
      _message('Demo withdrawal completed. No real money was transferred.');
      _refresh();
    } catch (error) {
      if (mounted) _message(friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(SellerWithdrawal withdrawal) async {
    try {
      await SellerPayoutService().cancelWithdrawal(withdrawal.id);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) _message(friendlyError(error));
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw earnings')),
      body: FutureBuilder<_WithdrawalData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Loading withdrawals...');
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _refresh);
          }
          final data = snapshot.data!;
          _accountId ??= data.accounts
              .where((account) => account.isDefault)
              .firstOrNull
              ?.id;
          _accountId ??= data.accounts.firstOrNull?.id;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.deepWater, AppColors.pondBlue],
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available balance',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        pesoCentavos(data.summary.availableCentavos),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: .35),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.science_outlined, color: AppColors.koiOrange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demo mode: confirming a withdrawal updates your '
                          'Tkoi wallet and history immediately, but does not '
                          'send real money to GCash or a bank.',
                        ),
                      ),
                    ],
                  ),
                ),
                if (data.summary.hasNegativeBalance) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'A refund reversal made your balance negative. Withdrawals will remain blocked until future Xendit earnings cover the amount.',
                    style: TextStyle(
                      color: AppColors.vermilion,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _amount,
                  enabled: !data.summary.hasNegativeBalance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₱ ',
                    helperText:
                        'Minimum ${pesoCentavos(data.summary.minimumWithdrawalCentavos)}',
                  ),
                ),
                const SizedBox(height: 12),
                if (data.accounts.isEmpty)
                  OutlinedButton.icon(
                    onPressed: _manageAccounts,
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Add payout account'),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(
                      labelText: 'Payout account',
                    ),
                    items: [
                      for (final account in data.accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            '${account.methodLabel} • ${account.maskedNumber}',
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _accountId = value),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _manageAccounts,
                      child: const Text('Manage payout accounts'),
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _submitting ||
                            data.accounts.isEmpty ||
                            data.summary.hasNegativeBalance
                        ? null
                        : () => _submit(data),
                    child: Text(
                      _submitting ? 'Processing...' : 'Demo withdraw',
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Withdrawal history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (data.withdrawals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No withdrawals yet',
                      message:
                          'Your requests and their status will appear here.',
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final withdrawal in data.withdrawals)
                          ListTile(
                            title: Text(
                              pesoCentavos(withdrawal.amountCentavos),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${withdrawal.method == 'gcash' ? 'GCash' : withdrawal.bankName ?? 'Bank'} ${withdrawal.maskedNumber}\n${withdrawal.statusLabel}',
                            ),
                            isThreeLine: true,
                            trailing: withdrawal.status == 'pending'
                                ? TextButton(
                                    onPressed: () => _cancel(withdrawal),
                                    child: const Text('Cancel'),
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WithdrawalData {
  final SellerWalletSummary summary;
  final List<SellerPayoutAccount> accounts;
  final List<SellerWithdrawal> withdrawals;

  const _WithdrawalData({
    required this.summary,
    required this.accounts,
    required this.withdrawals,
  });
}
