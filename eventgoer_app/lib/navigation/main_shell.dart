import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/my_tickets_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/resale_market_screen.dart';
import '../widgets/app_bottom_nav.dart';
import 'tab_index_notifier.dart';

/// The persistent app shell for the four bottom-nav tabs (Home, My
/// Tickets, Resale, Profile).
///
/// [AppBottomNav] lives here, in [Scaffold.bottomNavigationBar] — outside
/// the animated tab content — so it never moves when tabs slide in and
/// out. Tab bodies live in a [PageView] (swiping disabled; pages only
/// change via [_pageController.animateToPage]) so switching tabs slides
/// the outgoing tab off and the incoming tab in, while the bottom nav
/// bar underneath stays completely fixed.
///
/// Each tab is wrapped in [_KeepAliveTab] so its state (scroll position,
/// search text, etc.) survives being scrolled off-screen in the
/// [PageView] — matching the instant-switch [IndexedStack] this replaced.
///
/// This should be the only route pushed with `pushAndRemoveUntil` when
/// entering the main app (after login, registration, etc.) — every
/// other "jump to a tab" action elsewhere in the app goes through
/// [navigateToTab], which finds this shell already on the stack and
/// just switches its tab instead of creating a new one.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;
  late final PageController _pageController;

  static const _tabs = [
    DashboardScreen(),
    MyTicketsScreen(),
    ResaleMarketScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    mainShellTabIndex.value = _index;
    mainShellTabIndex.addListener(_onTabIndexChanged);
  }

  // Single source of truth for actually switching tabs. Both a bottom-nav
  // tap and an external navigateToTab() call funnel through here (via the
  // ValueNotifier) so there's exactly one place driving the animation —
  // no duplicate/competing animateToPage calls.
  void _onTabIndexChanged() {
    final target = mainShellTabIndex.value;
    if (!mounted || target == _index) return;
    setState(() => _index = target);
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onTabTapped(int index) {
    mainShellTabIndex.value = index;
  }

  @override
  void dispose() {
    mainShellTabIndex.removeListener(_onTabIndexChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        // Tabs switch only via the bottom nav (or navigateToTab), never
        // by the user dragging the page content itself.
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final tab in _tabs) _KeepAliveTab(child: tab)],
      ),
      bottomNavigationBar: AppBottomNav(currentIndex: _index, onTap: _onTabTapped),
    );
  }
}

/// Keeps a tab's State alive while it's scrolled off-screen in the
/// [PageView], so switching tabs and back doesn't reset scroll position,
/// search text, or in-progress input.
class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
