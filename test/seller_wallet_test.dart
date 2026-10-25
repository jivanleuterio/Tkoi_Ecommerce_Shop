import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/models/seller_wallet.dart';

void main() {
  group('seller wallet money logic', () {
    test('database money converts to integer centavos without floats', () {
      expect(centavosFromDatabase('1250.75'), 125075);
      expect(centavosFromDatabase('-80.50'), -8050);
      expect(centavosFromDatabase('100'), 10000);
    });

    test('five percent fee is rounded to centavos', () {
      expect(platformFeeCentavos(10000, '5.00'), 500);
      expect(platformFeeCentavos(1999, '5.00'), 100);
    });

    test('negative available balance remains visible', () {
      final summary = SellerWalletSummary.fromMap({
        'available_balance': '-75.25',
        'pending_balance': '100.00',
        'total_earned': '500.00',
        'total_withdrawn': '400.00',
        'minimum_withdrawal': '100.00',
        'platform_fee_percent': '5.00',
        'auto_release_days': 7,
      });
      expect(summary.availableCentavos, -7525);
      expect(summary.hasNegativeBalance, isTrue);
    });

    test('withdrawal input rejects more than two decimal places', () {
      expect(centavosFromInput('100.00'), 10000);
      expect(centavosFromInput('100.001'), isNull);
      expect(centavosFromInput('-5'), isNull);
    });

    test(
      'withdrawal validation enforces balance, minimum, and pending request',
      () {
        final summary = SellerWalletSummary.fromMap({
          'available_balance': '500.00',
          'pending_balance': '0',
          'total_earned': '500',
          'total_withdrawn': '0',
          'minimum_withdrawal': '100',
        });
        expect(
          validateWithdrawal(
            summary: summary,
            amountCentavos: 9999,
            hasPendingRequest: false,
          ),
          contains('Minimum'),
        );
        expect(
          validateWithdrawal(
            summary: summary,
            amountCentavos: 60000,
            hasPendingRequest: false,
          ),
          contains('exceeds'),
        );
        expect(
          validateWithdrawal(
            summary: summary,
            amountCentavos: 10000,
            hasPendingRequest: true,
          ),
          contains('pending'),
        );
        expect(
          validateWithdrawal(
            summary: summary,
            amountCentavos: 10000,
            hasPendingRequest: false,
          ),
          isNull,
        );
      },
    );
  });
}
