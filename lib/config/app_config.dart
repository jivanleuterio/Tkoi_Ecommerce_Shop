class AppConfig {
  // Loaded from `.env` through Flutter's --dart-define-from-file option.
  // The current public values remain as fallbacks so existing run/build
  // commands continue working while local and CI commands migrate.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kofbuodhxfjhvzbdorve.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_jIowD1FUu-vvAqvKh-hiyA_YlCvreto',
  );

  // Classroom mode: every online option uses Xendit's official Test Mode
  // simulator, so no real card, bank, or mobile-wallet details are required.
  // Change this to false only when Xendit Live Mode is fully configured.
  static const bool useXenditTestSimulator = bool.fromEnvironment(
    'USE_XENDIT_TEST_SIMULATOR',
    defaultValue: true,
  );
}
