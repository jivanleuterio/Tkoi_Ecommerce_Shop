import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../models/cart_item.dart';
import '../../models/online_payment.dart';
import '../../models/payment_option.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/error_view.dart';
import '../../widgets/current_location_button.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/tkoi_button.dart';
import 'payment_method_screen.dart';
import 'xendit_test_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  final String? buyNowProductId;

  const CheckoutScreen({super.key, required this.items, this.buyNowProductId});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _key = GlobalKey<FormState>();
  final _address = TextEditingController();
  late Future<void> _profileLoad;
  bool _placing = false;
  bool _checkingPayment = false;
  PaymentOption _paymentMethod = PaymentOption.cod;
  OnlinePayment? _onlinePayment;
  StreamSubscription<Uri>? _paymentLinkSubscription;

  bool get _usesTestSimulator =>
      AppConfig.useXenditTestSimulator && _paymentMethod.isOnline;

  @override
  void initState() {
    super.initState();
    _profileLoad = _loadAddress();
    _paymentLinkSubscription = AppLinks().uriLinkStream.listen(
      _handlePaymentReturn,
    );
  }

  Future<void> _loadAddress() async {
    final profile = await ProfileService().getMyProfile();
    _address.text = profile.address;
  }

  @override
  void dispose() {
    _paymentLinkSubscription?.cancel();
    _address.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_key.currentState!.validate()) return;
    if (_paymentMethod.isOnline) {
      await _startOnlinePayment();
      return;
    }

    setState(() => _placing = true);
    try {
      if (widget.buyNowProductId == null) {
        await OrderService().placeOrder(_address.text);
      } else {
        await OrderService().buyNow(
          productId: widget.buyNowProductId!,
          quantity: widget.items.first.quantity,
          deliveryAddress: _address.text,
        );
      }
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      var dialogOpen = true;
      final autoCloseTimer = Timer(const Duration(milliseconds: 1400), () {
        if (dialogOpen && mounted) navigator.pop();
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const AlertDialog(
          icon: Icon(Icons.check_circle, color: AppColors.success, size: 48),
          title: Text('Order placed'),
          content: Text(
            'Your Cash on Delivery order was sent to the seller. '
            'The seller can now review and update its delivery status.',
          ),
        ),
      ).whenComplete(() => dialogOpen = false);
      autoCloseTimer.cancel();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _startOnlinePayment() async {
    setState(() => _placing = true);
    try {
      final payment = await PaymentService().createXenditPayment(
        deliveryAddress: _address.text,
        paymentChannel: _paymentMethod.xenditChannel!,
        testSimulator: _usesTestSimulator,
        buyNowProductId: widget.buyNowProductId,
        quantity: widget.items.first.quantity,
      );
      if (!mounted) return;
      setState(() => _onlinePayment = payment);
      await _openOnlinePayment();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _choosePaymentMethod() async {
    final selected = await Navigator.push<PaymentOption>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(selected: _paymentMethod),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _paymentMethod = selected);
    }
  }

  Future<void> _openOnlinePayment() async {
    final payment = _onlinePayment;
    if (payment == null) return;
    if (payment.isTestSimulator) {
      final total = widget.items.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => XenditTestPaymentScreen(
            transactionId: payment.transactionId,
            amount: total,
            paymentMethodName: _paymentMethod.name,
          ),
        ),
      );
      if (paid == true && mounted) {
        await _checkOnlinePayment(showPendingMessage: true);
      }
      return;
    }
    final checkoutUrl = payment.checkoutUrl;
    if (checkoutUrl == null) return;
    final opened = await launchUrl(
      checkoutUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Xendit checkout.')),
      );
    }
  }

  Future<void> _handlePaymentReturn(Uri uri) async {
    if (uri.scheme != 'io.supabase.tkoi' || uri.host != 'payment-callback') {
      return;
    }
    final payment = _onlinePayment;
    if (payment == null ||
        uri.queryParameters['transaction_id'] != payment.transactionId) {
      return;
    }
    if (uri.queryParameters['result'] == 'cancel') {
      await _cancelOnlinePayment();
    } else {
      await _checkOnlinePayment(showPendingMessage: true);
    }
  }

  Future<void> _checkOnlinePayment({bool showPendingMessage = false}) async {
    final payment = _onlinePayment;
    if (payment == null || _checkingPayment) return;
    setState(() => _checkingPayment = true);
    try {
      final status = await PaymentService().getStatus(payment.transactionId);
      if (!mounted) return;
      if (status == 'paid') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment confirmed. Your order was sent to the seller.',
            ),
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else if (status == 'expired' ||
          status == 'failed' ||
          status == 'cancelled') {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.info_outline),
            title: const Text('Payment not completed'),
            content: Text(
              'The payment is $status. The order was cancelled and its stock was returned.',
            ),
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else if (showPendingMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Xendit is still confirming the payment. Check again shortly.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _checkingPayment = false);
    }
  }

  Future<void> _cancelOnlinePayment() async {
    final payment = _onlinePayment;
    if (payment == null || _checkingPayment) return;
    setState(() => _checkingPayment = true);
    try {
      await PaymentService().cancel(payment.transactionId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(
          icon: Icon(Icons.cancel_outlined),
          title: Text('Payment cancelled'),
          content: Text('The reserved fish stock has been returned.'),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _checkingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: FutureBuilder<void>(
        future: _profileLoad,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(
              message: 'Preparing secure checkout...',
            );
          }
          if (snapshot.hasError) return ErrorView(error: snapshot.error!);
          return Form(
            key: _key,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.waterGradient,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Review your order securely',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'CHECKOUT',
                        style: TextStyle(
                          color: AppColors.aqua,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Order summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      ...widget.items.map(
                        (item) => ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.cream,
                            child: Icon(
                              Icons.set_meal_rounded,
                              color: AppColors.koiOrange,
                            ),
                          ),
                          title: Text(
                            item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${item.quantity} × ${peso(item.product.price)}',
                          ),
                          trailing: Text(
                            peso(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          peso(total),
                          style: const TextStyle(
                            fontSize: 22,
                            color: AppColors.koiOrange,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('Delivery', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _address,
                  maxLines: 4,
                  maxLength: 300,
                  validator: (value) =>
                      Validators.address(value, label: 'Delivery address'),
                  decoration: InputDecoration(
                    labelText: 'Delivery address',
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: CurrentLocationButton(controller: _address),
                    helperText: 'Use GPS or enter your complete address.',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Payment method',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: Icon(
                      _usesTestSimulator
                          ? Icons.science_outlined
                          : _paymentMethod.isOnline
                          ? Icons.account_balance_wallet_outlined
                          : Icons.local_shipping_outlined,
                      color: _paymentMethod.isOnline
                          ? AppColors.pondBlue
                          : AppColors.koiOrange,
                    ),
                    title: Text(_paymentMethod.name),
                    subtitle: Text(_paymentMethod.description),
                    trailing: _onlinePayment == null
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Change'),
                              Icon(Icons.chevron_right),
                            ],
                          )
                        : const Icon(Icons.lock_outline),
                    onTap: _onlinePayment == null ? _choosePaymentMethod : null,
                  ),
                ),
                if (_paymentMethod.isOnline && _onlinePayment == null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.security,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _usesTestSimulator
                                ? 'A virtual payment will be processed by Xendit Test Mode. No real payment details are needed.'
                                : 'You will continue to Xendit to securely complete this payment.',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_onlinePayment != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waiting for ${_paymentMethod.name} payment',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _onlinePayment!.isTestSimulator
                                ? 'Open the test page and tap Proceed. No real money will be charged.'
                                : 'Complete payment in Xendit, then return here to check it.',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: _checkingPayment
                                    ? null
                                    : _openOnlinePayment,
                                child: Text(
                                  _onlinePayment!.isTestSimulator
                                      ? 'Open test payment'
                                      : 'Open secure payment',
                                ),
                              ),
                              FilledButton(
                                onPressed: _checkingPayment
                                    ? null
                                    : () => _checkOnlinePayment(
                                        showPendingMessage: true,
                                      ),
                                child: Text(
                                  _checkingPayment
                                      ? 'Checking...'
                                      : 'Check payment',
                                ),
                              ),
                              TextButton(
                                onPressed: _checkingPayment
                                    ? null
                                    : _cancelOnlinePayment,
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_onlinePayment == null)
                  TkoiButton(
                    onPressed: _placeOrder,
                    loading: _placing,
                    icon: _paymentMethod.isOnline
                        ? Icons.lock_rounded
                        : Icons.local_shipping_rounded,
                    label: _placing
                        ? 'Please wait...'
                        : !_paymentMethod.isOnline
                        ? 'Place COD order'
                        : 'Continue with ${_paymentMethod.name}',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
