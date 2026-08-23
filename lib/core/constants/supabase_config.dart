/// Supabase project config — used only for Storage (see storage_service.dart
/// for why). The anon key is Supabase's public client key by design (safe
/// to ship in the app binary, same as Firebase's config values) — it is
/// not a secret credential. Actual write access is governed by the bucket
/// policies configured in the Supabase dashboard, not by keeping this key
/// hidden.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://ykamplbqfzedmhwhaucj.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrYW1wbGJxZnplZG1od2hhdWNqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyNDc4MDgsImV4cCI6MjEwMjgyMzgwOH0.vh69LDQhBG8fcK_5w3ArqmpOcyjKCi6zXs2Pt4gd-jw';

  /// Single bucket for all app file uploads (profile photos under
  /// `profile_photos/`, receipts under `receipts/`) — see the SQL setup
  /// script in ADMIN_SETUP.md for how this bucket and its upload policy
  /// are created.
  static const String bucket = 'app-uploads';
}
