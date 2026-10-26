import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/utils/formatters.dart';
import 'package:tkoi_shop/utils/validators.dart';

void main() {
  group('Tkoi form security validation', () {
    test('rejects one-character identity and marketplace fields', () {
      expect(Validators.personName('a'), isNotNull);
      expect(Validators.username('a'), isNotNull);
      expect(
        Validators.text('a', 'Description', min: 20, max: 2000),
        isNotNull,
      );
      expect(Validators.address('a'), isNotNull);
    });

    test('requires a strong password', () {
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('Abcdefg1!'), isNull);
      expect(
        Validators.password(
          'Fisherman1!',
          username: 'fisherman',
          email: 'seller@gmail.com',
        ),
        isNotNull,
      );
    });

    test('validates Philippine mobile numbers and listing ranges', () {
      expect(Validators.phone('abc'), isNotNull);
      expect(Validators.phone('09171234567'), isNull);
      expect(Validators.phone('+639171234567'), isNull);
      expect(Validators.price('0'), isNotNull);
      expect(Validators.price('1000001'), isNotNull);
      expect(Validators.quantity('-1'), isNotNull);
      expect(Validators.age('1201'), isNotNull);
    });
  });

  test('missing transaction RPC has a beginner-friendly message', () {
    final message = friendlyError(
      'PostgrestException(message: Could not find the function '
      'public.buy_now, code: PGRST202)',
    );

    expect(message, contains('transaction update is not installed'));
    expect(message, contains('cart_transactions_fix.sql'));
    expect(message, isNot(contains('PostgrestException')));
  });

  test('expired OTP has a beginner-friendly recovery message', () {
    final message = friendlyError(
      'AuthApiException(message: Token has expired or is invalid, '
      'statusCode: 403, code: otp_expired)',
    );

    expect(message, contains('expired or no longer valid'));
    expect(message, contains('newest six-digit code'));
    expect(message, isNot(contains('AuthApiException')));
  });

  test('invalid login credentials do not expose a raw auth exception', () {
    final message = friendlyError(
      'AuthApiException(message: Invalid login credentials, '
      'statusCode: 400, code: invalid_credentials)',
    );

    expect(
      message,
      'Incorrect email or password. Check your details or create a new account.',
    );
    expect(message, isNot(contains('AuthApiException')));
  });

  test('missing phone verification helper has a friendly recovery message', () {
    final message = friendlyError(
      'PostgrestException(message: function public.is_phone_verified(uuid) '
      'does not exist, code: 42883)',
    );
    expect(message, contains('Rerun the updated migration 06'));
    expect(message, isNot(contains('PostgrestException')));
  });

  test('missing demo phone verification points to migration 18', () {
    final message = friendlyError(
      'PostgrestException(message: Could not find the function '
      'public.verify_demo_phone(p_phone), code: PGRST202)',
    );
    expect(message, contains('18_demo_phone_verification.sql'));
    expect(message, isNot(contains('PostgrestException')));
  });

  test('missing SMS provider has a useful explanation', () {
    final message = friendlyError(
      'AuthRetryableFetchException(message: Unable to get SMS provider, '
      'statusCode: 500)',
    );
    expect(message, contains('Real SMS is not configured'));
    expect(message, isNot(contains('AuthRetryableFetchException')));
  });

  test('missing demo payout RPC points to migration 08', () {
    final message = friendlyError(
      'PostgrestException(message: Could not find the function '
      'public.save_demo_seller_payout_account, code: PGRST202)',
    );
    expect(message, contains('08_demo_payout_accounts.sql'));
    expect(message, isNot(contains('PostgrestException')));
  });

  test('missing demo withdrawal RPC points to migration 10', () {
    final message = friendlyError(
      'PostgrestException(message: Could not find the function '
      'public.request_demo_seller_withdrawal, code: PGRST202)',
    );
    expect(message, contains('10_demo_withdrawal.sql'));
    expect(message, isNot(contains('PostgrestException')));
  });

  test('database validation errors do not expose PostgREST internals', () {
    final message = friendlyError(
      'PostgrestException(message: Verify your phone before adding a payout '
      'account., code: P0001, details: Bad Request)',
    );
    expect(message, 'Verify your phone before adding a payout account.');
    expect(message, isNot(contains('P0001')));
  });
}
