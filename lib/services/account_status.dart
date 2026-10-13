/// The message shown when someone signs in with an account an admin has
/// suspended or deactivated (`public.users.account_status`, see
/// supabase/schema.sql). Shared by the eventgoer, organizer and admin
/// logins so the wording matches everywhere.
///
/// This blocks NEW sign-ins only. Someone who is already signed in keeps
/// their session until it ends or they log out; nothing in the database
/// (RLS) looks at account_status yet.
String inactiveAccountMessage(String status) {
  switch (status) {
    case 'deactivated':
      return 'This account has been deactivated. Please contact FairTix support if you think this is a mistake.';
    default:
      return 'This account has been suspended. Please contact FairTix support if you think this is a mistake.';
  }
}
