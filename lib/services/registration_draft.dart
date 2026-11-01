/// Holds what the eventgoer typed on Registration Step 1 so the later steps
/// (email code, ID, selfie...) can show it and so it survives moving between
/// steps. Kept in memory only: nothing here is written to disk, and the
/// password is deliberately NOT stored here. It goes straight to Supabase Auth.
///
/// Step 1 clears it when it is left for good (back to Login, or registration
/// finished and the app moved on).
class RegistrationDraft {
  RegistrationDraft._();
  static final RegistrationDraft instance = RegistrationDraft._();

  String fullName = '';
  String email = '';

  void clear() {
    fullName = '';
    email = '';
  }
}
