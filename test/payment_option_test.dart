import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/models/payment_option.dart';

void main() {
  test('payment choices expose COD and unique Xendit channels', () {
    expect(PaymentOption.cod.isOnline, isFalse);
    expect(PaymentOption.gcash.xenditChannel, 'GCASH');
    expect(PaymentOption.cards.xenditChannel, 'CARDS');

    final onlineChannels = PaymentOption.values
        .where((option) => option.isOnline)
        .map((option) => option.xenditChannel)
        .toList();
    expect(onlineChannels.toSet().length, onlineChannels.length);
  });
}
