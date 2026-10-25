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
}
