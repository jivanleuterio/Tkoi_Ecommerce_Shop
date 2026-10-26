String peso(num value) => '₱${value.toStringAsFixed(2)}';

String compactCount(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}m';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
  }
  return value.toInt().toString();
}

String friendlyError(Object error) {
  final rawText = error.toString().replaceFirst('Exception: ', '');
  final postgrestMessage = RegExp(
    r'PostgrestException\(message:\s*(.*?),\s*(?:code|statusCode):',
    caseSensitive: false,
  ).firstMatch(rawText)?.group(1);
  final text = postgrestMessage?.trim() ?? rawText;
  final lower = rawText.toLowerCase();
  if (lower.contains('account is suspended')) {
    return 'Your account is suspended. You can only finish eligible existing orders and use Help & Support.';
  }
  if (lower.contains('account is banned')) {
    return 'Your account is banned. You can only submit an appeal.';
  }
  if (lower.contains('invalid_credentials') ||
      lower.contains('invalid login credentials')) {
    return 'Incorrect email or password. Check your details or create a new account.';
  }
  if (lower.contains('otp_expired') ||
      lower.contains('token has expired or is invalid')) {
    return 'This verification code is expired or no longer valid. '
        'Tap “Send another code” and enter only the newest six-digit code.';
  }
  if (lower.contains('otp') && lower.contains('invalid')) {
    return 'That verification code is incorrect. Check the newest email and '
        'enter all six digits.';
  }
  if (lower.contains('over_email_send_rate_limit') ||
      lower.contains('email rate limit')) {
    return 'Please wait before requesting another verification email.';
  }
  if (lower.contains('pgrst202') &&
      (lower.contains('buy_now') || lower.contains('add_to_cart'))) {
    return 'The Tkoi transaction update is not installed in Supabase yet. '
        'Run supabase/cart_transactions_fix.sql in the Supabase SQL Editor, '
        'then try again.';
  }
  if ((lower.contains('pgrst202') || lower.contains('pgrst205')) &&
      (lower.contains('get_chat_inbox') ||
          lower.contains('get_chat_context') ||
          lower.contains('send_chat_message') ||
          lower.contains('get_or_create_conversation') ||
          lower.contains('conversations') ||
          lower.contains('messages'))) {
    return 'Chat is not installed in Supabase yet. '
        'Run migrations 01 through 04 in order, then try again.';
  }
  if ((lower.contains('pgrst202') || lower.contains('pgrst205')) &&
      (lower.contains('submit_product_review') ||
          lower.contains('get_product_reviews') ||
          lower.contains('product_reviews') ||
          lower.contains('review_images'))) {
    return 'Product reviews are not installed in Supabase yet. '
        'Run migrations 01 through 03 in order, then try again.';
  }
  if ((lower.contains('pgrst202') || lower.contains('pgrst205')) &&
      (lower.contains('mark_order_received') ||
          lower.contains('submit_order_review') ||
          lower.contains('request_order_return') ||
          lower.contains('order_returns') ||
          lower.contains('order_reviews'))) {
    return 'Order reviews and returns are not installed in Supabase yet. '
        'Run supabase/order_aftercare.sql in the Supabase SQL Editor, then try again.';
  }
  if (lower.contains('save_demo_seller_payout_account') &&
      (lower.contains('pgrst202') || lower.contains('does not exist'))) {
    return 'Demo payout saving is not installed in Supabase yet. '
        'Run migration 08_demo_payout_accounts.sql, then try again.';
  }
  if (lower.contains('request_demo_seller_withdrawal') &&
      (lower.contains('pgrst202') || lower.contains('does not exist'))) {
    return 'Demo withdrawals are not installed in Supabase yet. '
        'Run migration 10_demo_withdrawal.sql, then try again.';
  }
  if ((lower.contains('pgrst202') || lower.contains('pgrst205')) &&
      (lower.contains('seller_wallet') ||
          lower.contains('withdrawal') ||
          lower.contains('payout'))) {
    return 'Seller earnings are not installed in Supabase yet. '
        'Run migrations 05, 06, and 07 in order, then try again.';
  }
  if (lower.contains('is_phone_verified') &&
      (lower.contains('42883') || lower.contains('does not exist'))) {
    return 'Phone verification support is not installed in Supabase yet. '
        'Rerun the updated migration 06, then try again.';
  }
  if (lower.contains('verify_demo_phone') &&
      (lower.contains('pgrst202') || lower.contains('does not exist'))) {
    return 'Demo phone verification is not installed in Supabase yet. '
        'Run migration 18_demo_phone_verification.sql, then try again.';
  }
  if (lower.contains('unable to get sms provider')) {
    return 'Real SMS is not configured for this Supabase project. '
        'Use Tkoi demo phone verification or configure an SMS provider.';
  }
  if ((lower.contains('pgrst202') || lower.contains('pgrst205')) &&
      (lower.contains('support_ticket') ||
          lower.contains('create_report') ||
          lower.contains('admin_list_tickets'))) {
    return 'Help & Support is not installed in Supabase yet. '
        'Run migration 13_support_and_reports.sql, then try again.';
  }
  if (lower.contains('socket') || lower.contains('network')) {
    return 'No internet connection. Please try again.';
  }
  return text;
}
