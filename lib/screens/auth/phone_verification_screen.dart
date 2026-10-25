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
  final _code = TextEditingController();
  late Future<AppProfile> _profile;
  AppProfile? _loadedProfile;
  bool _codeSent = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<AppProfile> _loadProfile() async {
    final profile = await ProfileService().getMyProfile();
    _loadedProfile = profile;
    _phone.text = _toPhilippineE164(profile.mobileNumber);
    return profile;
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
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

  Future<void> _sendCode() async {
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
      await AuthService().requestPhoneVerification(phone);
      if (!mounted) return;
      setState(() {
        _phone.text = phone;
        _codeSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code requested.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the six-digit phone code.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().verifyPhoneCode(phone: _phone.text, code: _code.text);
      final profile = _loadedProfile;
      if (profile != null) {
        await ProfileService().updateProfile(
          fullName: profile.fullName,
          username: profile.username,
          mobileNumber: _phone.text,
          address: profile.address,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number verified. You can now sell fish.'),
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
                          'A verified contact number is required before creating or managing a fish shop.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _phone,
                          enabled: !_codeSent,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            hintText: '+639171234567',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        if (_codeSent) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 7,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'SMS verification code',
                              counterText: '',
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _loading
                              ? null
                              : _codeSent
                              ? _verify
                              : _sendCode,
                          child: Text(
                            _loading
                                ? 'Please wait...'
                                : _codeSent
                                ? 'Verify phone number'
                                : 'Send verification code',
                          ),
                        ),
                        if (_codeSent)
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                    _codeSent = false;
                                    _code.clear();
                                  }),
                            child: const Text('Use a different number'),
                          ),
                        const SizedBox(height: 10),
                        const Text(
                          'Real SMS delivery requires a configured Supabase SMS provider. For classroom testing, use a configured test number and test OTP.',
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
