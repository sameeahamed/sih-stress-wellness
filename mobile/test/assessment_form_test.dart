import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/api_client.dart';
import 'package:sih_stress_wellness/core/models.dart';
import 'package:sih_stress_wellness/core/session.dart';
import 'package:sih_stress_wellness/features/assessment/assessment_form_screen.dart';
import 'package:sih_stress_wellness/features/results/prediction_result_screen.dart';

import 'fake_api.dart';

void main() {
  Future<({AuthController controller, FakeApiClient api})> pumpForm(
    WidgetTester tester, {
    FakeApiClient? api,
  }) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final harness = await authenticatedController(api: api);
    await tester.pumpWidget(
      MaterialApp(home: AssessmentFormScreen(controller: harness.controller)),
    );
    await tester.pumpAndSettle();
    return harness;
  }

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
  Future<void> answerForm(
    WidgetTester tester, {
    String rest = '6.5',
    String sleep = '5.5',
  }) async {
    await tester.enterText(
      find.byKey(const Key('assessment-rest-hours')),
      rest,
    );
    await tester.enterText(
      find.byKey(const Key('assessment-sleep-hours')),
      sleep,
    );
    await tester.pumpAndSettle();
    await tapScale(tester, 0, 7);
    await tapScale(tester, 1, 8);
  }

  testWidgets('shows the synthetic notice and disclaimer', (tester) async {
    await pumpForm(tester);
    expect(find.text('SYNTHETIC DEMO DATA'), findsOneWidget);
    expect(
      find.text('This is a risk indicator, not a medical diagnosis.'),
      findsOneWidget,
    );
    expect(find.text('Submit assessment'), findsOneWidget);
  });

  testWidgets('requires both rating questions before submitting', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('assessment-rest-hours')),
      '6.5',
    );
    await tester.enterText(
      find.byKey(const Key('assessment-sleep-hours')),
      '5.5',
    );
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Please answer both rating questions'),
      findsOneWidget,
    );
    expect(find.byType(AssessmentFormScreen), findsOneWidget);
  });

  testWidgets('validates hours fields against the backend range', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(
      find.byKey(const Key('assessment-rest-hours')),
      '25',
    );
    await tester.enterText(
      find.byKey(const Key('assessment-sleep-hours')),
      '30',
    );
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Must be between 0 and 24 hours'), findsNWidgets(2));
  });

  testWidgets('submits and shows the redesigned prediction result', (
    tester,
  ) async {
    await pumpForm(tester);
    await answerForm(tester);

    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(find.byType(PredictionResultScreen), findsOneWidget);

    // A large, plain-language result rather than a bare badge.
    expect(find.text('High'), findsWidgets);
    // An uncalibrated model output is shown as a score, never as a
    // probability of a medical condition.
    expect(
      find.textContaining('Model score for this level: 0.70'),
      findsOneWidget,
    );
    expect(
      find.textContaining('not the chance of a medical condition'),
      findsOneWidget,
    );
    expect(
      find.textContaining('an authorised welfare officer or commander can see it'),
      findsWidgets,
    );
    // Probabilities are shown as percentages.
    expect(find.text('10%'), findsWidgets);
    expect(find.text('20%'), findsWidgets);
    expect(find.text('70%'), findsWidgets);
    // Ranked contributing factors with the "not medical causes" framing.
    expect(find.text('Why this assessment?'), findsOneWidget);
    expect(find.text('Factors contributing toward higher risk'), findsOneWidget);
    expect(find.text('Elevated weekly duty hours'), findsOneWidget);
    expect(find.textContaining('not medical causes'), findsWidgets);
    // Human-in-the-loop panel for HIGH.
    expect(find.text('A human decides, not the model'), findsOneWidget);
    // The provenance panel, disclaimer and way-forward actions all sit below
    // the fold on a phone, so the list is scrolled to the last action before
    // they are looked for.
    await tester.scrollUntilVisible(
      find.text('Back to home'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('This is a risk indicator, not a medical diagnosis.'), findsOneWidget);
    expect(find.text('About this result'), findsOneWidget);
    expect(find.text('Version v1'), findsOneWidget);
    expect(find.textContaining('synthetic demo data'), findsOneWidget);
    expect(find.text('See my history'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
    // The provenance row reports a record state, not a promised workflow.
    expect(
      find.text('Not yet actioned by a welfare officer'),
      findsOneWidget,
    );
  });

  testWidgets('shows an API error surfaced by the backend', (tester) async {
    final api = FakeApiClient()
      ..submitAssessmentError = const ApiException(
        422,
        'Assessment data cannot be used for prediction',
      );
    await pumpForm(tester, api: api);
    await answerForm(tester);

    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Assessment data cannot be used for prediction'),
      findsOneWidget,
    );
    expect(find.byType(AssessmentFormScreen), findsOneWidget);
  });

  testWidgets('skipped prediction explains the cause and the way forward', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..onSubmitAssessment = () => AssessmentSubmitResponse(
        assessment: WellnessAssessment(
          id: 'a1',
          personnelKey: '11111111-1111-1111-1111-111111111111',
          stressLevelSelfReport: 3,
          restHours7d: 8,
          sleepHours7d: 7,
          workloadScore: 3,
          submittedAt: DateTime.utc(2026, 9, 21, 10),
          createdAt: DateTime.utc(2026, 9, 21, 10),
        ),
        prediction: null,
        predictionSkippedReason:
            'Not enough duty data to run a stress-risk prediction',
      );
    await pumpForm(tester, api: api);
    await answerForm(tester, rest: '8.0', sleep: '7.0');

    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Your check-in was saved'), findsOneWidget);
    expect(
      find.text('Not enough duty data to run a stress-risk prediction'),
      findsOneWidget,
    );
    // The user is told how to fix it.
    expect(find.textContaining('at least one duty record'), findsOneWidget);
    expect(find.text('High'), findsNothing);
  });
}
