import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sih_stress_wellness/core/token_store.dart';
import 'package:sih_stress_wellness/main.dart';

import 'fake_api.dart';

void main() {
  testWidgets('app boots into the login screen without a stored session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      SihStressWellnessApp(
        apiClient: FakeApiClient(),
        tokenStore: InMemoryTokenStore(),
      ),
    );
    // The branded restore state is shown while the session is being checked.
    expect(find.text('Restoring your secure session…'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // The package name must never be shown to a user.
    expect(find.text('sih_stress_wellness'), findsNothing);
  });
}
