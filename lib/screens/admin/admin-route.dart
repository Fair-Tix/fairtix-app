import 'package:flutter/material.dart';

String adminRouteName(Widget page) => '/${page.runtimeType}';

void adminPushReplacement(BuildContext context, Widget page) {
  Navigator.pushReplacementNamed(context, adminRouteName(page));
}

void adminPushAndRemoveUntil(BuildContext context, Widget page) {
  Navigator.pushNamedAndRemoveUntil(
    context,
    adminRouteName(page),
    (route) => false,
  );
}

Route<T> adminPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: adminRouteName(page)),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => page,
  );
}
