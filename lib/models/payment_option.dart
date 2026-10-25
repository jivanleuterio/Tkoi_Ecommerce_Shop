class PaymentOption {
  final String id;
  final String name;
  final String description;
  final String? xenditChannel;

  const PaymentOption({
    required this.id,
    required this.name,
    required this.description,
    this.xenditChannel,
  });

  bool get isOnline => xenditChannel != null;

  static const cod = PaymentOption(
    id: 'cod',
    name: 'Cash on Delivery',
    description: 'Pay when your fish order arrives.',
  );
  static const gcash = PaymentOption(
    id: 'gcash',
    name: 'GCash',
    description: 'Pay securely using your GCash account.',
    xenditChannel: 'GCASH',
  );
  static const maya = PaymentOption(
    id: 'maya',
    name: 'Maya',
    description: 'Pay using your Maya wallet.',
    xenditChannel: 'PAYMAYA',
  );
  static const cards = PaymentOption(
    id: 'cards',
    name: 'Credit or debit card',
    description: 'Visa, Mastercard, and supported cards.',
    xenditChannel: 'CARDS',
  );
  static const bpi = PaymentOption(
    id: 'bpi',
    name: 'BPI Online Banking',
    description: 'Continue securely through BPI.',
    xenditChannel: 'BPI_ONLINE_BANKING',
  );
  static const bdo = PaymentOption(
    id: 'bdo',
    name: 'BDO Online Banking',
    description: 'Continue securely through BDO.',
    xenditChannel: 'BDO_ONLINE_BANKING',
  );
  static const unionBank = PaymentOption(
    id: 'unionbank',
    name: 'UnionBank Online Banking',
    description: 'Continue securely through UnionBank.',
    xenditChannel: 'UNIONBANK_ONLINE_BANKING',
  );
  static const qrph = PaymentOption(
    id: 'qrph',
    name: 'QRPh',
    description: 'Scan using a supported bank or e-wallet app.',
    xenditChannel: 'QRPH',
  );
  static const values = [cod, gcash, maya, cards, bpi, bdo, unionBank, qrph];
}
