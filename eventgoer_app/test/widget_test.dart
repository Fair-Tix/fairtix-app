// Basic smoke test for the FairTix app.
//
// This just verifies the app boots to the Splash screen without throwing.
// TODO: expand with real widget tests as screens stabilize.

import 'package:flutter_test/flutter_test.dart';

import 'package:fairtix/main.dart';

void main() {
  testWidgets('App boots to Splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FairTixApp());

    expect(find.text('FairTix'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
