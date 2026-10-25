import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/seller_payout.dart';
import '../../models/shop.dart';
import '../../services/seller_payout_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_skeleton.dart';

class PayoutAccountsScreen extends StatefulWidget {
  final Shop shop;

  const PayoutAccountsScreen({super.key, required this.shop});

  @override
  State<PayoutAccountsScreen> createState() => _PayoutAccountsScreenState();
}

class _PayoutAccountsScreenState extends State<PayoutAccountsScreen> {
  late Future<List<SellerPayoutAccount>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = SellerPayoutService().getAccounts(widget.shop.id);
  }

  void _refresh() => setState(_load);

  Future<void> _edit([SellerPayoutAccount? account]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PayoutAccountForm(shop: widget.shop, account: account),
    );
    if (changed == true) _refresh();
  }

  Future<void> _delete(SellerPayoutAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payout account?'),
        content: Text('${account.methodLabel} ${account.maskedNumber}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SellerPayoutService().deleteAccount(account.id);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add demo account'),
      ),
      body: FutureBuilder<List<SellerPayoutAccount>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(message: 'Loading payout accounts...');
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _refresh);
          }
          final accounts = snapshot.data ?? const [];
          if (accounts.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No payout account yet',
              message:
                  'Add demo GCash or bank details before testing a withdrawal.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: accounts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final account = accounts[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.aqua.withValues(alpha: .14),
                    child: Icon(
                      account.method == 'gcash'
                          ? Icons.phone_android_rounded
                          : Icons.account_balance_rounded,
                      color: AppColors.pondBlue,
                    ),
                  ),
                  title: Text(account.methodLabel),
                  subtitle: Text(
                    '${account.accountName}\n${account.maskedNumber}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'edit' ? _edit(account) : _delete(account),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  titleAlignment: ListTileTitleAlignment.center,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PayoutAccountForm extends StatefulWidget {
  final Shop shop;
  final SellerPayoutAccount? account;

  const _PayoutAccountForm({required this.shop, this.account});

  @override
  State<_PayoutAccountForm> createState() => _PayoutAccountFormState();
}

class _PayoutAccountFormState extends State<_PayoutAccountForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _number;
  late final TextEditingController _bank;
  late String _method;
  late bool _default;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.account?.accountName);
    _number = TextEditingController(text: widget.account?.accountNumber);
    _bank = TextEditingController(text: widget.account?.bankName);
    _method = widget.account?.method ?? 'gcash';
    _default = widget.account?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _bank.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await SellerPayoutService().saveDemoAccount(
        shopId: widget.shop.id,
        accountId: widget.account?.id,
        method: _method,
        accountName: _name.text,
        accountNumber: _number.text,
        bankName: _method == 'bank' ? _bank.text : null,
        isDefault: _default,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.account == null
                    ? 'Add demo payout account'
                    : 'Edit demo payout account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: const Text(
                  'Demo only: these details are saved for testing and are not '
                  'verified with GCash or a bank. No real money is sent.',
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'gcash', label: Text('GCash')),
                  ButtonSegment(value: 'bank', label: Text('Bank')),
                ],
                selected: {_method},
                onSelectionChanged: (value) {
                  setState(() => _method = value.first);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Account name'),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Enter the account holder name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _number,
                keyboardType: _method == 'gcash'
                    ? TextInputType.phone
                    : TextInputType.text,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                decoration: InputDecoration(
                  labelText: _method == 'gcash'
                      ? 'GCash number'
                      : 'Account number',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Enter an account number or demo ID.'
                    : null,
              ),
              if (_method == 'bank') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bank,
                  decoration: const InputDecoration(labelText: 'Bank name'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter the bank name.'
                      : null,
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use as default'),
                value: _default,
                onChanged: (value) => setState(() => _default = value),
              ),
              if (_errorMessage case final message?) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.vermilion.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    border: Border.all(
                      color: AppColors.vermilion.withValues(alpha: .25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.vermilion,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(color: AppColors.vermilion),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Saving...' : 'Save demo payout account',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
