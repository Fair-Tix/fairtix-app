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
import 'screens/user/login_screen.dart' show LoginScreen, userHomeFor;
import 'screens/user/app_loading_screen.dart';
import 'theme/fairtix_palette.dart';
import 'theme/theme_controller.dart';
import 'theme/page_transitions.dart';
import 'services/admin_auth_service.dart';
import 'services/organizer_auth_service.dart';
import 'services/organizer_session.dart';
import 'services/user_auth_service.dart';
import 'services/user_session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved Light / Dark choice before the first frame, so the launch
  // splash already paints in the right mode (a quick local read).
  await ThemeController.instance.load();
  final startup = _startup();

  if (kIsWeb) {
    // Web keeps its existing flow (organizer splash handles the first view).
    final result = await startup;
    runApp(
      FairTixThemeScope(
        controller: ThemeController.instance,
        child: MyApp(
          initialRoute: result.initialRoute,
          startupAuthError: result.startupAuthError,
        ),
      ),
    );
    return;
  }

  // Mobile: paint the FairTix loading screen on the first frame and let the
  // startup work below run behind it.
  runApp(
    FairTixThemeScope(
      controller: ThemeController.instance,
      child: _AppRoot(startup: startup),
    ),
  );
}

/// Everything that used to run in main() before runApp: Supabase, saved theme,
/// and restoring any signed-in session.
Future<_StartupResult> _startup() async {
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

  return _StartupResult(
    initialRoute: initialRoute,
    startupAuthError: startupAuthError,
  );
}

class _StartupResult {
  const _StartupResult({this.initialRoute = '/', this.startupAuthError});

  final String initialRoute;
  final String? startupAuthError;
}

/// Mobile root: shows [AppLoadingScreen] until startup finishes, then fades
/// into the real app. Lives above MaterialApp, so the splash only ever shows
/// once per launch and never during normal navigation.
class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.startup});

  final Future<_StartupResult> startup;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  _StartupResult _result = const _StartupResult();
  bool _showApp = false;

  late final Future<void> _ready = widget.startup.then<void>(
    (result) {
      _result = result;
    },
    onError: (Object error, StackTrace stack) {
      // Never leave the user stuck on the splash. Fall through to the normal
      // first screen; the error is logged for debugging.
      debugPrint('FairTix startup failed: $error\n$stack');
    },
  );

  @override
  Widget build(BuildContext context) {
    // The dark base behind the cross-fade keeps the window background from
    // showing through while the two screens swap.
    return ColoredBox(
      color: FairTixPalette.of(context).gradientBottom,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _showApp
              ? MyApp(
                  key: const ValueKey('app'),
                  initialRoute: _result.initialRoute,
                  startupAuthError: _result.startupAuthError,
                )
              : _LoadingApp(
                  key: const ValueKey('loading'),
                  ready: _ready,
                  onFinished: () => setState(() => _showApp = true),
                ),
        ),
      ),
    );
  }
}

/// Minimal MaterialApp host for the loading screen (it needs Material,
/// Directionality and MediaQuery, which exist only below a MaterialApp).
class _LoadingApp extends StatelessWidget {
  const _LoadingApp({super.key, required this.ready, required this.onFinished});

  final Future<void> ready;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairTix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      builder: (context, child) =>
          MediaQuery.withNoTextScaling(child: child ?? const SizedBox.shrink()),
      home: AppLoadingScreen(ready: ready, onFinished: onFinished),
    );
  }
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
              return user != null ? userHomeFor(user) : const LoginScreen();
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
