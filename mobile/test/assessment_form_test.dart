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
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final harness = await authenticatedController(api: api);
    await tester.pumpWidget(
      MaterialApp(home: AssessmentFormScreen(controller: harness.controller)),
    );
    await tester.pumpAndSettle();
    return harness;
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

  testWidgets('validates hours fields against the backend range', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '25');
    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Must be between 0 and 24 hours'), findsNWidgets(2));
  });

  testWidgets('submits and shows the prediction result', (tester) async {
    await pumpForm(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '6.5');
    await tester.enterText(find.byType(TextFormField).at(1), '5.5');
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(find.byType(PredictionResultScreen), findsOneWidget);
    expect(find.text('HIGH'), findsNWidgets(2));
    expect(find.text('Contributing factors'), findsOneWidget);
    expect(
      find.text('This is a risk indicator, not a medical diagnosis.'),
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

    await tester.enterText(find.byType(TextFormField).at(0), '6.5');
    await tester.enterText(find.byType(TextFormField).at(1), '5.5');
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(
      find.text('Assessment data cannot be used for prediction'),
      findsOneWidget,
    );
    expect(find.byType(AssessmentFormScreen), findsOneWidget);
  });

  testWidgets('skipped prediction shows the reason instead of a risk level',
      (tester) async {
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

    await tester.enterText(find.byType(TextFormField).at(0), '8.0');
    await tester.enterText(find.byType(TextFormField).at(1), '7.0');
    await tester.tap(find.text('Submit assessment'));
    await tester.pumpAndSettle();

    expect(
      find.text('Not enough duty data to run a stress-risk prediction'),
      findsOneWidget,
    );
    expect(find.text('HIGH'), findsNothing);
  });
}