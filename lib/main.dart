import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'screens/admin/admin-accounts.dart';
import 'screens/admin/admin-announcement.dart';
import 'screens/admin/admin-dashboard.dart';
import 'screens/admin/admin-events-tickets.dart';
import 'screens/admin/admin-fraud-alerts.dart';
import 'screens/admin/admin-login.dart';
import 'screens/admin/admin-organizer-applications.dart';
import 'screens/admin/admin-platform-settings.dart';
import 'screens/admin/admin-profile.dart';
import 'screens/admin/admin-resale-monitoring.dart';
import 'screens/admin/admin-revenue-reports.dart';
import 'screens/admin/admin-route.dart';
import 'screens/organizer/organizer-splash.dart';
import 'screens/organizer/organizer-landing.dart';
import 'screens/organizer/app_colors.dart';
import 'screens/user/splash_screen.dart';
import 'services/admin_auth_service.dart';
import 'services/organizer_auth_service.dart';
import 'services/organizer_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  final requestedRoute = kIsWeb ? Uri.base.fragment : null;
  final isAdminRoute = requestedRoute?.startsWith('/Admin') ?? false;
  var initialRoute = requestedRoute ?? '/';
  String? startupAuthError;

  if (kIsWeb) {
    var adminRestored = false;
    try {
      adminRestored = await AdminAuthService.instance.restoreSession();
      if (adminRestored) {
        // Signed-in admin: deep links stay as-is, but the public site and
        // the login page itself both go to the dashboard.
        if (!isAdminRoute || initialRoute == '/AdminLoginScreen') {
          initialRoute = '/AdminDashboardScreen';
        }
      } else if (isAdminRoute) {
        initialRoute = '/AdminLoginScreen';
      }
    } on AdminAuthException catch (e) {
      if (isAdminRoute) {
        initialRoute = '/AdminLoginScreen';
        startupAuthError = e.message;
      }
    } catch (_) {
      // Anything unexpected (e.g. no network) must never stop the app from
      // starting. The Supabase session is left alone, so a refresh retries.
      if (isAdminRoute) initialRoute = '/AdminLoginScreen';
    }

    // Keep an organizer signed in across a browser refresh. The restored
    // account is read back by the fallback route in MyApp.build below.
    if (!adminRestored && !isAdminRoute) {
      try {
        await OrganizerAuthService.instance.restoreSession();
      } catch (_) {
        // Same rule: fall through to the splash screen, never crash.
      }
    }
  }

  runApp(
    MyApp(initialRoute: initialRoute, startupAuthError: startupAuthError),
  );
}

/// Convenience accessor used throughout the app's service layer, e.g.
/// `supabase.from('users')...` or `supabase.auth.signInWithPassword(...)`.
final SupabaseClient supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.initialRoute,
    this.startupAuthError,
  });

  final String? initialRoute;
  final String? startupAuthError;

  Widget? _adminPageForRoute(String? routeName) => switch (routeName) {
    '/AdminAccountsScreen' => const AdminAccountsScreen(),
    '/AdminAnnouncementScreen' => const AdminAnnouncementScreen(),
    '/AdminDashboardScreen' => const AdminDashboardScreen(),
    '/AdminEventsTicketsScreen' => const AdminEventsTicketsScreen(),
    '/AdminFraudAlertsScreen' => const AdminFraudAlertsScreen(),
    '/AdminLoginScreen' => const AdminLoginScreen(),
    '/AdminOrganizerApplicationsScreen' =>
      const AdminOrganizerApplicationsScreen(),
    '/AdminPlatformSettingsScreen' => const AdminPlatformSettingsScreen(),
    '/AdminProfileScreen' => const AdminProfileScreen(),
    '/AdminResaleMonitoringScreen' => const AdminResaleMonitoringScreen(),
    '/AdminRevenueReportsScreen' => const AdminRevenueReportsScreen(),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairTix',
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute ?? '/',
      onGenerateRoute: (settings) {
        final adminPage = settings.name == '/AdminLoginScreen'
            ? AdminLoginScreen(initialErrorText: startupAuthError)
            : _adminPageForRoute(settings.name);
        if (adminPage != null) return adminPageRoute(adminPage);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) {
            if (!kIsWeb) return const SplashScreen();
            // A signed-in organizer (restored after a refresh, or logged in
            // this session) goes straight to where they belong; everyone
            // else sees the public splash screen. Read live from the
            // session so a Log Out is respected.
            final organizer = OrganizerSession.instance.account;
            return organizer != null
                ? organizerLandingFor(organizer)
                : const OrganizerSplashScreen();
          },
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F9FC),
      ),
    );
  }
}
