/// Supabase project connection details.
///
/// These values should be provided at build time so they are not committed to
/// source control. Example:
///
/// flutter run --dart-define=SUPABASE_URL=https://project.supabase.co --dart-define=SUPABASE_ANON_KEY=publishable-key
///
/// The anon/publishable key is safe to ship in client code by design — it only
/// grants whatever access your Postgres Row-Level Security (RLS) policies allow
/// (see supabase/policies.sql). It is NOT a secret the way a service_role key
/// would be.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
