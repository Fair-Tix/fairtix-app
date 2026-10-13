/// Supabase project connection details.
///
/// The anon/publishable key is safe to ship in client code by design — it
/// only grants whatever access your Postgres Row-Level Security (RLS)
/// policies allow (see supabase/policies.sql). It is NOT a secret the way
/// a service_role key would be. Still, for a public GitHub repo, consider
/// moving these two values to `--dart-define` build-time variables instead
/// of hardcoding them here, so they aren't sitting in git history.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://wxbwpximftdgrnanypce.supabase.co';
  static const String publishableKey =
      'sb_publishable_4PmATkd_abXT4lcgaFxOhg_DXEx90_D';

  @Deprecated('Use publishableKey instead.')
  static const String anonKey = publishableKey;
}
