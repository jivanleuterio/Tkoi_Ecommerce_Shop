import 'package:flutter/material.dart';

import '../../models/app_profile.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_view.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/cart_action.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final VoidCallback? onVerified;

  const PhoneVerificationScreen({super.key, this.onVerified});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phone = TextEditingController();
  late Future<AppProfile> _profile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<AppProfile> _loadProfile() async {
    final profile = await ProfileService().getMyProfile();
    _phone.text = _toPhilippineE164(profile.mobileNumber);
    return profile;
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String _toPhilippineE164(String input) {
    var value = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('09') && value.length == 11) {
      value = '+63${value.substring(1)}';
    } else if (value.startsWith('9') && value.length == 10) {
      value = '+63$value';
    } else if (value.startsWith('63') && !value.startsWith('+')) {
      value = '+$value';
    }
    return value;
  }

  bool _validPhone(String phone) =>
      RegExp(r'^\+[1-9]\d{9,14}$').hasMatch(phone);

  Future<void> _verifyForDemo() async {
    final phone = _toPhilippineE164(_phone.text);
    if (!_validPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid number such as +639171234567.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().verifyPhoneForDemo(phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Demo phone verification complete. You can now sell fish.',
          ),
        ),
      );
      widget.onVerified?.call();
      if (Navigator.canPop(context)) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify phone to sell'),
        actions: const [CartAction(), SizedBox(width: 6)],
      ),
      body: FutureBuilder<AppProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TkoiLoadingView(
              message: 'Checking your phone verification...',
            );
          }
          if (snapshot.hasError) return ErrorView(error: snapshot.error!);
          return KoiBackdrop(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: TkoiFormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.phone_android,
                          size: 70,
                          color: AppColors.pondBlue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Seller phone verification',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'A contact number is required before creating or managing a fish shop.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.science_outlined),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Demo mode: this number is verified instantly for testing. No SMS is sent.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            hintText: '+639171234567',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _loading ? null : _verifyForDemo,
                          child: Text(
                            _loading
                                ? 'Please wait...'
                                : 'Verify number for demo',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Before publishing a production app, disable demo verification and configure a real SMS provider in Supabase Auth.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
