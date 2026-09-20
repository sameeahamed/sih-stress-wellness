import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/token_store.dart';
import 'package:sih_stress_wellness/main.dart';

import 'fake_api.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, FakeApiClient api) async {
    await tester.pumpWidget(
      SihStressWellnessApp(
        apiClient: api,
        tokenStore: InMemoryTokenStore(),
      ),
    );
  }

  testWidgets('shows the login screen when no session exists', (tester) async {
    await pumpApp(tester, FakeApiClient());
    await tester.pumpAndSettle();

    expect(find.text('Personnel App'), findsOneWidget);
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

    expect(find.text('Incorrect username or password'), findsOneWidget);
    expect(find.text('Personnel App'), findsOneWidget);
  });

  testWidgets('logs in and lands on the personnel home screen', (tester) async {
    final api = FakeApiClient();
    await pumpApp(tester, api);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'demo_personnel');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo-password-123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Personnel Home'), findsOneWidget);
    expect(find.text('demo_personnel'), findsOneWidget);
    expect(find.text('Personnel key'), findsOneWidget);
    expect(find.text('11111111-1111-1111-1111-111111111111'), findsOneWidget);
    expect(find.text('Wellness Assessment'), findsOneWidget);
    expect(find.text('Duty Record'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('log out returns the user to the login screen', (tester) async {
    final api = FakeApiClient();
    final store = InMemoryTokenStore();
    await store.write('test-token');
    await tester.pumpWidget(
      SihStressWellnessApp(apiClient: api, tokenStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personnel Home'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('Personnel App'), findsOneWidget);
    expect(await store.read(), isNull);
  });
}