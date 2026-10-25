class OnlinePayment {
  final String transactionId;
  final Uri? checkoutUrl;
  final bool isTestSimulator;

  const OnlinePayment({
    required this.transactionId,
    required this.checkoutUrl,
    required this.isTestSimulator,
  });

  factory OnlinePayment.fromMap(Map<String, dynamic> map) {
    final transactionId = map['transaction_id'] as String?;
    final isTestSimulator = map['test_mode'] == true;
    final rawUrl = map['checkout_url'] as String?;
    final checkoutUrl = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (transactionId == null ||
        (!isTestSimulator && (checkoutUrl == null || !checkoutUrl.hasScheme))) {
      throw const FormatException('The payment server returned invalid data.');
    }
    return OnlinePayment(
      transactionId: transactionId,
      checkoutUrl: checkoutUrl,
      isTestSimulator: isTestSimulator,
    );
  }
}
