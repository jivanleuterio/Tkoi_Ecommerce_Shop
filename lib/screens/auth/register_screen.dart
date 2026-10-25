import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/current_location_button.dart';
import '../../widgets/tkoi_button.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _username,
      _email,
      _mobile,
      _address,
      _password,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await AuthService().register(
        fullName: _fullName.text,
        username: _username.text,
        email: _email.text,
        mobileNumber: _mobile.text,
        address: _address.text,
        password: _password.text,
      );
      if (!mounted) return;
      if (result.session == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
          ),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator ?? (value) => Validators.text(value, label),
        decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your Tkoi account')),
      body: KoiBackdrop(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const TkoiWordmark(height: 64),
                  const SizedBox(height: 12),
                  Text(
                    'Join the Tkoi community',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'One account lets you discover, buy, and sell fish.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.softGray),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.large),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Form(
                      key: _key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FormSectionTitle(
                            icon: Icons.person_outline_rounded,
                            title: 'About you',
                          ),
                          const SizedBox(height: 12),
                          _field(
                            _fullName,
                            'Full name',
                            maxLength: 80,
                            validator: Validators.personName,
                          ),
                          _field(
                            _username,
                            'Username',
                            maxLength: 30,
                            validator: Validators.username,
                          ),
                          const _FormSectionTitle(
                            icon: Icons.contact_mail_outlined,
                            title: 'Contact & delivery',
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              maxLength: 254,
                              validator: Validators.email,
                              decoration: const InputDecoration(
                                labelText: 'Email or Gmail',
                              ),
                            ),
                          ),
                          _field(
                            _mobile,
                            'Mobile number',
                            keyboardType: TextInputType.phone,
                            maxLength: 16,
                            validator: Validators.phone,
                          ),
                          _field(
                            _address,
                            'Complete address',
                            maxLines: 3,
                            maxLength: 300,
                            validator: (value) => Validators.address(
                              value,
                              label: 'Complete address',
                            ),
                            suffixIcon: CurrentLocationButton(
                              controller: _address,
                            ),
                          ),
                          const _FormSectionTitle(
                            icon: Icons.shield_outlined,
                            title: 'Secure your account',
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: TextFormField(
                              controller: _password,
                              obscureText: _hidePassword,
                              maxLength: 72,
                              validator: (value) => Validators.password(
                                value,
                                username: _username.text,
                                email: _email.text,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          TextFormField(
                            controller: _confirmPassword,
                            obscureText: _hidePassword,
                            maxLength: 72,
                            validator: (value) => value != _password.text
                                ? 'Passwords do not match.'
                                : Validators.password(
                                    value,
                                    username: _username.text,
                                    email: _email.text,
                                  ),
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TkoiButton(
                            label: _loading
                                ? 'Creating account...'
                                : 'Create account',
                            loading: _loading,
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _register,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'By registering, you agree to keep Tkoi safe and respectful.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.softGray),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FormSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.mist,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.pondBlue),
      ),
      const SizedBox(width: 10),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
