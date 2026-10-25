import 'package:flutter/material.dart';

import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/tkoi_button.dart';

class XenditTestPaymentScreen extends StatefulWidget {
  final String transactionId;
  final double amount;
  final String paymentMethodName;

  const XenditTestPaymentScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.paymentMethodName,
  });

  @override
  State<XenditTestPaymentScreen> createState() =>
      _XenditTestPaymentScreenState();
}

class _XenditTestPaymentScreenState extends State<XenditTestPaymentScreen> {
  bool _processing = false;
  String? _error;

  Future<void> _proceed() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final status = await PaymentService().simulateTestPayment(
        widget.transactionId,
      );
      if (!mounted) return;
      if (status == 'paid') {
        final navigator = Navigator.of(context, rootNavigator: true);
        var dialogOpen = true;
        final dialogFuture = showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            icon: Icon(Icons.verified, color: AppColors.success, size: 48),
            title: Text('Test payment successful'),
            content: Text(
              'Xendit Test Mode confirmed the virtual payment. No real money was charged.',
            ),
          ),
        ).whenComplete(() => dialogOpen = false);
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;
        if (dialogOpen) navigator.pop();
        await dialogFuture;
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _error = 'Xendit is still processing the simulation. Tap Proceed again shortly.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xendit test payment')),
      body: KoiBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  gradient: AppColors.waterGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Proceed to Xendit',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is a virtual Xendit payment for classroom testing. You will not enter a real card, bank account, or mobile number.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Payment method'),
                    trailing: Text(widget.paymentMethodName),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Tkoi order total'),
                    trailing: Text(
                      peso(widget.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            TkoiButton(
              onPressed: _proceed,
              loading: _processing,
              icon: Icons.lock_open_rounded,
              label: _processing ? 'Processing...' : 'Proceed to Xendit',
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _processing
                  ? null
                  : () => Navigator.pop(context, false),
              child: const Text('Back to checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
