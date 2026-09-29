import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/api_client.dart';
import 'package:sih_stress_wellness/core/session.dart';
import 'package:sih_stress_wellness/core/token_store.dart';
import 'package:sih_stress_wellness/features/assessment/assessment_form_screen.dart';
import 'package:sih_stress_wellness/features/history/history_screen.dart';
import 'package:sih_stress_wellness/features/results/prediction_result_screen.dart';
import 'package:sih_stress_wellness/main.dart';

import 'fake_api.dart';

/// Taps a value on one of the two 1-10 rating scales.
Future<void> tapScale(WidgetTester tester, int question, int value) async {
  final cell = find.descendant(
    of: find.byType(ScaleQuestion).at(question),
    matching: find.text('$value'),
  );
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

/// Answers both 1-10 questions and fills the two hours fields.
Future<void> answerAssessment(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('assessment-rest-hours')), '6.5');
  await tester.enterText(
    find.byKey(const Key('assessment-sleep-hours')),
    '5.5',
  );
  await tester.pumpAndSettle();
  await tapScale(tester, 0, 7);
  await tapScale(tester, 1, 8);
}

void main() {
  testWidgets('expired stored token on startup returns to login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = FakeApiClient()..failRestoreWith401 = true;
    final store = InMemoryTokenStore();
    await store.write('stale-token');
    await tester.pumpWidget(
      SihStressWellnessApp(apiClient: api, tokenStore: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
    expect(await store.read(), isNull);
  });

  testWidgets('a 401 during assessment returns to the login screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = FakeApiClient()
      ..submitAssessmentError = const ApiException(401, 'Session expired');
    final store = InMemoryTokenStore();
    await store.write('test-token');
    await tester.pumpWidget(
      SihStressWellnessApp(apiClient: api, tokenStore: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wellness Assessment'));
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentFormScreen), findsOneWidget);

    await answerAssessment(tester);
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
    expect(await store.read(), isNull);
  });

  testWidgets('complete happy path: login → home → assessment → prediction '
      '→ history → logout', (tester) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = FakeApiClient();
    await tester.pumpWidget(
      SihStressWellnessApp(apiClient: api, tokenStore: InMemoryTokenStore()),
    );
    await tester.pumpAndSettle();

    // Login
    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'demo_personnel');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'demo-password-123',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Home
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Welcome, demo_personnel'), findsOneWidget);

    // Assessment
    await tester.tap(find.text('Wellness Assessment'));
    await tester.pumpAndSettle();
    await answerAssessment(tester);
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    // Prediction result
    expect(find.byType(PredictionResultScreen), findsOneWidget);
    expect(find.text('High'), findsWidgets);
    expect(find.text('A human decides, not the model'), findsOneWidget);

    // History (empty for the fake). The action sits below the fold.
    await tester.scrollUntilVisible(
      find.text('See my history'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('See my history'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(
      find.textContaining('You have not completed a wellness check-in yet'),
      findsOneWidget,
    );

    // Back to home, then logout
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Personnel Stress & Welfare'), findsOneWidget);
  });

  group('AuthController (unit)', () {
    test(
      'login returns a message instead of throwing on bad credentials',
      () async {
        final api = FakeApiClient()..failLogin = true;
        final store = InMemoryTokenStore();
        final controller = AuthController(api: api, tokenStore: store);
        await controller.restore();
        expect(controller.status, AuthStatus.unauthenticated);

        final error = await controller.login('x', 'y');
        expect(error, 'Incorrect username or password');
        expect(controller.status, AuthStatus.unauthenticated);
        expect(await store.read(), isNull);
      },
    );

    test('logout clears the token and the user', () async {
      final harness = await authenticatedController();
      expect(harness.controller.status, AuthStatus.authenticated);
      expect(harness.controller.user, isNotNull);

      await harness.controller.logout();
      expect(harness.controller.status, AuthStatus.unauthenticated);
      expect(harness.controller.token, isNull);
      expect(harness.controller.user, isNull);
    });
  });
}
