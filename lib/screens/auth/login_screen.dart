import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/koi_backdrop.dart';
import '../../widgets/tkoi_button.dart';
import '../../widgets/tkoi_text_field.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService().signIn(email: _email.text, password: _password.text);
    } catch (error) {
      final errorText = error.toString().toLowerCase();
      if (mounted &&
          (errorText.contains('email_not_confirmed') ||
              errorText.contains('email not confirmed'))) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              email: _email.text.trim(),
              initialResendDelay: 0,
            ),
          ),
        );
        return;
      }
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
      body: KoiBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const TkoiWordmark(height: 78),
                    const SizedBox(height: 14),
                    Text(
                      'Welcome to Tkoi',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Discover remarkable fish from trusted local sellers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.softGray),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.large),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 18),
                            TkoiTextField(
                              controller: _email,
                              label: 'Email address',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 14),
                            TkoiTextField(
                              controller: _password,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.done,
                              validator: (value) =>
                                  Validators.required(value, 'Password'),
                              onSubmitted: (_) => _loading ? null : _submit(),
                              suffix: IconButton(
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            TkoiButton(
                              label: _loading ? 'Signing in...' : 'Sign in',
                              loading: _loading,
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 12),
                            TkoiButton(
                              label: 'Create an account',
                              secondary: true,
                              icon: Icons.person_add_alt_1_outlined,
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Secure email sign-in • Phone verification is required only for sellers',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.softGray),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
