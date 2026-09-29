import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/token_store.dart';
import 'package:sih_stress_wellness/main.dart';

import 'fake_api.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, FakeApiClient api) async {
    await tester.pumpWidget(
      SihStressWellnessApp(apiClient: api, tokenStore: InMemoryTokenStore()),
    );
  }

  testWidgets('shows the login screen when no session exists', (tester) async {
    await pumpApp(tester, FakeApiClient());
    await tester.pumpAndSettle();

    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('SYNTHETIC DEMO DATA'), findsOneWidget);
  });

  testWidgets('shows a validation error when fields are empty', (tester) async {
    await pumpApp(tester, FakeApiClient());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows an inline error for invalid credentials', (tester) async {
    final api = FakeApiClient()
      ..failLogin = true
      ..loginErrorDetail = 'Incorrect username or password';
    await pumpApp(tester, api);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'nobody');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Sign-in failed. Check your username and password'),
      findsOneWidget,
    );
    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
  });

  testWidgets('logs in and lands on the personnel home screen', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = FakeApiClient();
    await pumpApp(tester, api);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'demo_personnel');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'demo-password-123',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Welcome, demo_personnel'), findsOneWidget);
    // Role is shown in the header pill and again in the profile card.
    expect(find.text('Personnel'), findsNWidgets(2));
    expect(find.text('Personnel key'), findsOneWidget);
    // The opaque key is shown truncated, not as a full 36-character UUID.
    expect(find.text('11111111…1111'), findsOneWidget);
    expect(find.text('11111111-1111-1111-1111-111111111111'), findsNothing);
    expect(find.text('Wellness Assessment'), findsOneWidget);
    expect(find.text('Duty Record'), findsOneWidget);
    expect(find.text('My History'), findsOneWidget);
  });

  testWidgets('log out asks for confirmation before ending the session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = FakeApiClient();
    final store = InMemoryTokenStore();
    await store.write('test-token');
    await tester.pumpWidget(
      SihStressWellnessApp(apiClient: api, tokenStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    expect(await store.read(), 'test-token');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
    expect(await store.read(), isNull);
  });
}
