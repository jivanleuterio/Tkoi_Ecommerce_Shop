import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> register({
    required String fullName,
    required String username,
    required String email,
    required String mobileNumber,
    required String address,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'username': username.trim(),
        'mobile_number': mobileNumber.trim(),
        'address': address.trim(),
      },
    );
  }

  Future<AuthResponse> verifyEmailCode({
    required String email,
    required String code,
  }) {
    return _client.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.email,
    );
  }

  Future<void> resendSignupCode(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  bool get isPhoneVerified {
    final user = currentUser;
    return user?.phone != null &&
        user!.phone!.isNotEmpty &&
        user.phoneConfirmedAt != null;
  }

  Future<void> requestPhoneVerification(String phone) async {
    await _client.auth.updateUser(UserAttributes(phone: phone));
  }

  Future<void> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    await _client.auth.verifyOTP(
      phone: phone,
      token: code.trim(),
      type: OtpType.phoneChange,
    );
    await _client.auth.refreshSession();
  }

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'io.supabase.tkoi://reset-callback',
      );

  Future<void> updatePassword(String password) =>
      _client.auth.updateUser(UserAttributes(password: password));

  Future<void> signOut() => _client.auth.signOut();
}
