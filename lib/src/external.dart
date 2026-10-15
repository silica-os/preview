// What reaches outside the app: under `flutter test` nothing may talk to the user's session
// (the portal would open a real Open dialog on the machine running the tests).

import 'dart:io';

/// True under `flutter test`: nothing may start programs or open dialogs on the machine running
/// the tests.
bool get startsNothing => Platform.environment.containsKey('FLUTTER_TEST');
