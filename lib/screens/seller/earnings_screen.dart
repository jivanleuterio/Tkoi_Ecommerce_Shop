import 'package:flutter/material.dart';

import '../../models/seller_wallet.dart';
import '../../models/shop.dart';
import '../../services/seller_wallet_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';
import 'payout_accounts_screen.dart';
import 'withdrawal_screen.dart';

class EarningsScreen extends StatefulWidget {
  final Shop shop;

  const EarningsScreen({super.key, required this.shop});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  static const filters = {
    'all': 'All',
    'earnings': 'Earnings',
    'fees': 'Fees',
    'withdrawals': 'Withdrawals',
    'refunds': 'Refunds',
  };
  late Future<SellerWalletSummary> _summaryFuture;
  late Future<List<SellerWalletTransaction>> _transactionsFuture;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summaryFuture = SellerWalletService().getSummary(widget.shop.id);
    _transactionsFuture = SellerWalletService().getTransactions(
      widget.shop.id,
      filter: _filter,
    );
  }

  void _refresh() => setState(_load);

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            tooltip: 'Refresh earnings',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<SellerWalletSummary>(
        future: _summaryFuture,
        builder: (context, summarySnapshot) {
          if (summarySnapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Loading your earnings...');
          }
          if (summarySnapshot.hasError) {
            return ErrorView(error: summarySnapshot.error!, onRetry: _refresh);
          }
          final summary = summarySnapshot.data ?? SellerWalletSummary.empty;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (summary.hasNegativeBalance)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.vermilion.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: const Text(
                      'Your balance is negative because released earnings were reversed after a refund. New withdrawals are blocked until future earnings cover it.',
                      style: TextStyle(
                        color: AppColors.vermilion,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.45,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _BalanceCard(
                      label: 'Available',
                      amount: summary.availableCentavos,
                      color: AppColors.pondBlue,
                    ),
                    _BalanceCard(
                      label: 'Pending escrow',
                      amount: summary.pendingCentavos,
                      color: AppColors.gold,
                    ),
                    _BalanceCard(
                      label: 'Total earned',
                      amount: summary.totalEarnedCentavos,
                      color: AppColors.success,
                    ),
                    _BalanceCard(
                      label: 'Withdrawn',
                      amount: summary.totalWithdrawnCentavos,
                      color: AppColors.koiOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PayoutAccountsScreen(shop: widget.shop),
                          ),
                        ),
                        icon: const Icon(Icons.account_balance_outlined),
                        label: const Text('Payout accounts'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: summary.hasNegativeBalance
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WithdrawalScreen(shop: widget.shop),
                                  ),
                                );
                                if (mounted) _refresh();
                              },
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Withdraw'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Only Xendit-paid orders enter this wallet. COD revenue is shown in sales analytics but is paid directly to you.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final entry in filters.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            onSelected: (_) {
                              setState(() {
                                _filter = entry.key;
                                _transactionsFuture = SellerWalletService()
                                    .getTransactions(
                                      widget.shop.id,
                                      filter: _filter,
                                    );
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                FutureBuilder<List<SellerWalletTransaction>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(friendlyError(snapshot.error!)),
                      );
                    }
                    final transactions = snapshot.data ?? const [];
                    if (transactions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 12, bottom: 8),
                        child: EmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No wallet activity yet',
                          message: 'Paid Xendit orders and withdrawals will appear here.',
                        ),
                      );
                    }
                    return Card(
                      margin: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          for (final transaction in transactions)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: transaction.amountCentavos < 0
                                    ? AppColors.vermilion.withValues(alpha: .1)
                                    : AppColors.aqua.withValues(alpha: .14),
                                child: Icon(
                                  transaction.amountCentavos < 0
                                      ? Icons.south_east_rounded
                                      : Icons.north_east_rounded,
                                  color: transaction.amountCentavos < 0
                                      ? AppColors.vermilion
                                      : AppColors.pondBlue,
                                ),
                              ),
                              title: Text(transaction.title),
                              subtitle: Text(
                                '${_date(transaction.createdAt)} • ${transaction.status}',
                              ),
                              trailing: Text(
                                pesoCentavos(transaction.amountCentavos),
                                style: TextStyle(
                                  color: transaction.amountCentavos < 0
                                      ? AppColors.vermilion
                                      : AppColors.success,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;

  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            pesoCentavos(amount),
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
