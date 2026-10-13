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
import 'screens/organizer/app_colors.dart';
import 'screens/user/splash_screen.dart';
import 'services/admin_auth_service.dart';

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
    try {
      final isAdmin = await AdminAuthService.instance.restoreSession();
      if (isAdmin) {
        if (!isAdminRoute) initialRoute = '/AdminDashboardScreen';
      } else if (isAdminRoute) {
        initialRoute = '/AdminLoginScreen';
      }
    } on AdminAuthException catch (e) {
      if (isAdminRoute) {
        initialRoute = '/AdminLoginScreen';
        startupAuthError = e.message;
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
          builder: (_) =>
              kIsWeb ? const OrganizerSplashScreen() : const SplashScreen(),
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
