import 'package:flutter/material.dart';

import '../../models/payment_option.dart';
import '../../theme/app_colors.dart';

class PaymentMethodScreen extends StatelessWidget {
  final PaymentOption selected;

  const PaymentMethodScreen({super.key, required this.selected});

  IconData _icon(PaymentOption option) => switch (option.id) {
    'cod' => Icons.local_shipping_outlined,
    'gcash' => Icons.account_balance_wallet_outlined,
    'maya' => Icons.wallet_outlined,
    'cards' => Icons.credit_card,
    'qrph' => Icons.qr_code_2,
    _ => Icons.account_balance_outlined,
  };

  Widget _section(
    BuildContext context,
    String title,
    List<PaymentOption> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: options.map((option) {
              final isSelected = option.id == selected.id;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? AppColors.cream
                      : AppColors.mist,
                  child: Icon(
                    _icon(option),
                    color: isSelected
                        ? AppColors.koiOrange
                        : AppColors.pondBlue,
                  ),
                ),
                title: Text(option.name),
                subtitle: Text(option.description),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, option),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose payment method')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.waterGradient,
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.aqua, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Choose how you want to pay. Your order details remain protected.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _section(context, 'Pay on delivery', const [PaymentOption.cod]),
          _section(context, 'E-wallets', const [
            PaymentOption.gcash,
            PaymentOption.maya,
          ]),
          _section(context, 'Cards', const [PaymentOption.cards]),
          _section(context, 'Online banking', const [
            PaymentOption.bpi,
            PaymentOption.bdo,
            PaymentOption.unionBank,
          ]),
          _section(context, 'Other options', const [PaymentOption.qrph]),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Online methods currently use Xendit Test Mode for classroom testing. No real card, bank, or wallet details are required.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
