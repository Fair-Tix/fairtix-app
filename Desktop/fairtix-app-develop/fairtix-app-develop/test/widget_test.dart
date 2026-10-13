// Basic smoke test for the FairTix organizer app entry point.

import 'package:flutter_test/flutter_test.dart';

import 'package:fairtix_app/main.dart';

void main() {
  testWidgets('App launches on the organizer splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // The organizer splash screen should be showing, with entry points into
    // the login and registration flows.
    expect(find.text('FairTix'), findsWidgets);
    expect(find.text('Organizer Log In'), findsWidgets);
    expect(find.text('Apply as Organizer'), findsOneWidget);
  });
}
