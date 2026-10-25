int centavosFromDatabase(Object? value) {
  if (value == null) return 0;
  final text = value.toString().trim();
  if (text.isEmpty) return 0;
  final negative = text.startsWith('-');
  final unsigned = negative ? text.substring(1) : text;
  final parts = unsigned.split('.');
  final pesos = int.tryParse(parts.first) ?? 0;
  final fraction = parts.length < 2 ? '00' : '${parts[1]}00'.substring(0, 2);
  final result = pesos * 100 + (int.tryParse(fraction) ?? 0);
  return negative ? -result : result;
}

int? centavosFromInput(String value) {
  final clean = value.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) return null;
  return centavosFromDatabase(clean);
}

String pesoCentavos(int centavos) {
  final negative = centavos < 0;
  final absolute = centavos.abs();
  final pesos = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}₱$pesos.$cents';
}

int platformFeeCentavos(int grossCentavos, String percent) {
  final percentHundredths = centavosFromDatabase(percent);
  return (grossCentavos * percentHundredths + 5000) ~/ 10000;
}

String? validateWithdrawal({
  required SellerWalletSummary summary,
  required int amountCentavos,
  required bool hasPendingRequest,
}) {
  if (summary.hasNegativeBalance) {
    return 'Withdrawals are blocked until future earnings cover the refund reversal.';
  }
  if (hasPendingRequest) {
    return 'You already have a pending withdrawal request.';
  }
  if (amountCentavos < summary.minimumWithdrawalCentavos) {
    return 'Minimum withdrawal is ${pesoCentavos(summary.minimumWithdrawalCentavos)}.';
  }
  if (amountCentavos > summary.availableCentavos) {
    return 'That amount exceeds your available balance.';
  }
  return null;
}

class SellerWalletSummary {
  final int availableCentavos;
  final int pendingCentavos;
  final int totalEarnedCentavos;
  final int totalWithdrawnCentavos;
  final int minimumWithdrawalCentavos;
  final String platformFeePercent;
  final int autoReleaseDays;

  const SellerWalletSummary({
    required this.availableCentavos,
    required this.pendingCentavos,
    required this.totalEarnedCentavos,
    required this.totalWithdrawnCentavos,
    required this.minimumWithdrawalCentavos,
    required this.platformFeePercent,
    required this.autoReleaseDays,
  });

  bool get hasNegativeBalance => availableCentavos < 0;

  factory SellerWalletSummary.fromMap(Map<String, dynamic> map) =>
      SellerWalletSummary(
        availableCentavos: centavosFromDatabase(map['available_balance']),
        pendingCentavos: centavosFromDatabase(map['pending_balance']),
        totalEarnedCentavos: centavosFromDatabase(map['total_earned']),
        totalWithdrawnCentavos: centavosFromDatabase(map['total_withdrawn']),
        minimumWithdrawalCentavos: centavosFromDatabase(
          map['minimum_withdrawal'],
        ),
        platformFeePercent: map['platform_fee_percent']?.toString() ?? '5.00',
        autoReleaseDays: (map['auto_release_days'] as num? ?? 7).toInt(),
      );

  static const empty = SellerWalletSummary(
    availableCentavos: 0,
    pendingCentavos: 0,
    totalEarnedCentavos: 0,
    totalWithdrawnCentavos: 0,
    minimumWithdrawalCentavos: 10000,
    platformFeePercent: '5.00',
    autoReleaseDays: 7,
  );
}

class SellerWalletTransaction {
  final String id;
  final String? orderId;
  final String type;
  final int amountCentavos;
  final String status;
  final String note;
  final DateTime createdAt;

  const SellerWalletTransaction({
    required this.id,
    required this.orderId,
    required this.type,
    required this.amountCentavos,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  factory SellerWalletTransaction.fromMap(Map<String, dynamic> map) =>
      SellerWalletTransaction(
        id: map['id'] as String,
        orderId: map['order_id'] as String?,
        type: map['type'] as String? ?? 'adjustment',
        amountCentavos: centavosFromDatabase(map['amount']),
        status: map['status'] as String? ?? 'pending',
        note: map['note'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  String get title => switch (type) {
    'sale_pending' => 'Sale in escrow',
    'sale_released' => 'Sale released',
    'platform_fee' => 'Platform fee',
    'refund_reversal' => 'Refund reversal',
    'withdrawal' => 'Withdrawal requested',
    'withdrawal_reversal' => 'Withdrawal returned',
    _ => 'Wallet adjustment',
  };
}
