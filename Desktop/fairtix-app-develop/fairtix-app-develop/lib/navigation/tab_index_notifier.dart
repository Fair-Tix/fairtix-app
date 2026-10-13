import 'package:flutter/foundation.dart';

/// Global tab-index signal so screens pushed on top of [MainShell] can
/// ask it to switch tabs (e.g. "Back to My Tickets" from deep in the
/// Resale flow) without rebuilding or animating the bottom nav itself.
/// [MainShell] listens to this; nothing else should need to.
final ValueNotifier<int> mainShellTabIndex = ValueNotifier<int>(0);
