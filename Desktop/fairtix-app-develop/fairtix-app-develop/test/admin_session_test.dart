import 'package:flutter_test/flutter_test.dart';

import 'package:fairtix_app/services/admin_session.dart';

void main() {
  test('admin session stores the signed-in email', () {
    AdminSession.instance.signOut();
    AdminSession.instance.signIn('admin@fairtix.com');

    expect(AdminSession.instance.currentEmail, 'admin@fairtix.com');
    expect(AdminSession.instance.isSignedIn, isTrue);
  });
}
