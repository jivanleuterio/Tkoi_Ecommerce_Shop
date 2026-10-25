class AppConfig {
  // Replace with your Supabase Project URL and Anon (Public) Key
  static const String supabaseUrl = 'https://kofbuodhxfjhvzbdorve.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_jIowD1FUu-vvAqvKh-hiyA_YlCvreto';

  // Classroom mode: every online option uses Xendit's official Test Mode
  // simulator, so no real card, bank, or mobile-wallet details are required.
  // Change this to false only when Xendit Live Mode is fully configured.
  static const bool useXenditTestSimulator = true;
}
