import 'seller_wallet.dart';

class SellerPayoutAccount {
  final String id;
  final String shopId;
  final String method;
  final String accountName;
  final String accountNumber;
  final String? bankName;
  final bool isDefault;

  const SellerPayoutAccount({
    required this.id,
    required this.shopId,
    required this.method,
    required this.accountName,
    required this.accountNumber,
    required this.bankName,
    required this.isDefault,
  });

  factory SellerPayoutAccount.fromMap(Map<String, dynamic> map) =>
      SellerPayoutAccount(
        id: map['id'] as String,
        shopId: map['shop_id'] as String,
        method: map['method'] as String? ?? 'gcash',
        accountName: map['account_name'] as String? ?? '',
        accountNumber: map['account_number'] as String? ?? '',
        bankName: map['bank_name'] as String?,
        isDefault: map['is_default'] as bool? ?? false,
      );

  String get methodLabel => method == 'gcash' ? 'GCash' : bankName ?? 'Bank';

  String get maskedNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  }
}

class SellerWithdrawal {
  final String id;
  final int amountCentavos;
  final String method;
  final String accountName;
  final String accountNumber;
  final String? bankName;
  final String status;
  final String adminNote;
  final String? externalReference;
  final bool isDemo;
  final DateTime requestedAt;

  const SellerWithdrawal({
    required this.id,
    required this.amountCentavos,
    required this.method,
    required this.accountName,
    required this.accountNumber,
    required this.bankName,
    required this.status,
    required this.adminNote,
    required this.externalReference,
    required this.isDemo,
    required this.requestedAt,
  });

  factory SellerWithdrawal.fromMap(Map<String, dynamic> map) =>
      SellerWithdrawal(
        id: map['id'] as String,
        amountCentavos: centavosFromDatabase(map['amount']),
        method: map['payout_method'] as String? ?? 'gcash',
        accountName: map['account_name_snapshot'] as String? ?? '',
        accountNumber: map['account_number_snapshot'] as String? ?? '',
        bankName: map['bank_name_snapshot'] as String?,
        status: map['status'] as String? ?? 'pending',
        adminNote: map['admin_note'] as String? ?? '',
        externalReference: map['external_reference'] as String?,
        isDemo: map['is_demo'] as bool? ?? false,
        requestedAt:
            DateTime.tryParse(map['requested_at'] as String? ?? '') ??
            DateTime.now(),
      );

  String get statusLabel {
    if (isDemo && status == 'paid') return 'Demo paid';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  String get maskedNumber => accountNumber.length <= 4
      ? accountNumber
      : '•••• ${accountNumber.substring(accountNumber.length - 4)}';
}
