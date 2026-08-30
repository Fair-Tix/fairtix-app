import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'screens/organizer/organizer-splash.dart';
import 'screens/organizer/app_colors.dart';
import 'screens/user/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    throw FlutterError(
      'Supabase is not configured. Pass --dart-define=SUPABASE_URL=... and '
      '--dart-define=SUPABASE_ANON_KEY=... when running the app.',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const MyApp());
}

/// Convenience accessor used throughout the app's service layer, e.g.
/// `supabase.from('users')...` or `supabase.auth.signInWithPassword(...)`.
final SupabaseClient supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairTix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F9FC),
      ),
      // Web build = organizer/admin portal (OrganizerSplashScreen has
      // buttons for both "Organizer Log In" and "Admin Portal", so both
      // roles are reachable for testing from this one entry point).
      // Mobile build = the attendee-facing app.
      home: kIsWeb ? const OrganizerSplashScreen() : const SplashScreen(),
    );
  }
}
