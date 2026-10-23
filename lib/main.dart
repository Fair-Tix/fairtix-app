import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
import 'screens/admin/admin-user-registrations.dart';
import 'screens/organizer/organizer-splash.dart';
import 'screens/organizer/organizer-landing.dart';
import 'screens/organizer/app_colors.dart';
import 'screens/user/login_screen.dart' show userHomeFor;
import 'screens/user/splash_screen.dart';
import 'theme/theme_controller.dart';
import 'theme/page_transitions.dart';
import 'services/admin_auth_service.dart';
import 'services/organizer_auth_service.dart';
import 'services/organizer_session.dart';
import 'services/user_auth_service.dart';
import 'services/user_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  // Restore the saved Light/Dark choice before the first frame.
  await ThemeController.instance.load();
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

  if (!kIsWeb) {
    // Mobile app: keep the eventgoer signed in across app restarts until
    // they press Log Out. Supabase persists the session on the device; this
    // rebuilds UserSession from it. Never blocks startup on failure.
    try {
      await UserAuthService.instance.restoreSession();
    } catch (_) {
      // Fall through to the splash screen.
    }
  }

  runApp(
    FairTixThemeScope(
      controller: ThemeController.instance,
      child: MyApp(
        initialRoute: initialRoute,
        startupAuthError: startupAuthError,
      ),
    ),
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
    '/AdminUserRegistrationsScreen' => const AdminUserRegistrationsScreen(),
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
            if (!kIsWeb) {
              // A restored eventgoer skips the splash/login and goes straight
              // to where they belong. Read live so a Log Out is respected.
              final user = UserSession.instance.account;
              return user != null ? userHomeFor(user) : const SplashScreen();
            }
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
        pageTransitionsTheme: smoothPageTransitionsTheme,
        scaffoldBackgroundColor: const Color(0xFFF9F9FC),
      ),
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        var data = media.copyWith(
          // Respect the user's font size, but cap it so fixed-height pieces
          // (buttons, nav bars, cards) don't break on very large text.
          textScaler: media.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.2,
          ),
        );
        Widget content = child ?? const SizedBox.shrink();

        if (!kIsWeb && media.size.width > _phoneMaxWidth) {
          // The phone app on a tablet / foldable / landscape: keep the phone
          // layout centered instead of stretching it edge to edge. Children
          // see the narrower width through MediaQuery as well.
          data = data.copyWith(
            size: Size(_phoneMaxWidth, media.size.height),
          );
          content = ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: SizedBox(width: _phoneMaxWidth, child: content),
            ),
          );
        }

        return MediaQuery(data: data, child: content);
      },
    );
  }
}

/// Widest the phone (eventgoer) app is allowed to get, in logical pixels.
const double _phoneMaxWidth = 560;

/// Lets mouse and trackpad users drag-scroll as well as touch users, so every
/// scrolling screen behaves the same on web, desktop and phones.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
