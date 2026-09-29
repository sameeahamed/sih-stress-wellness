/// Widget tests for the SIMULATED AI wellness check-in concept screen.
///
/// These assert the two properties that matter for the demo: it is labelled as
/// a simulation, and the conversational answers are submitted through the
/// EXISTING assessment API so the prediction comes from the real backend
/// pipeline rather than being produced on-device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/api_client.dart';
import 'package:sih_stress_wellness/core/models.dart';
import 'package:sih_stress_wellness/features/checkin/wellness_checkin_screen.dart';
import 'package:sih_stress_wellness/features/results/prediction_result_screen.dart';

import 'fake_api.dart';

void main() {
  Future<void> pumpCheckin(WidgetTester tester, FakeApiClient api) async {
    // A phone-sized viewport is far shorter than these screens, so the default
    // 800x600 test surface leaves most of the content below the fold. A tall
    // surface renders each screen in full and keeps the assertions readable.
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = await authenticatedController(api: api);
    await tester.pumpWidget(
      MaterialApp(
        home: WellnessCheckinScreen(controller: harness.controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The intro list is taller than the default test viewport, so the primary
  /// action has to be scrolled into view before it can be tapped.
  Future<void> startCheckin(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start simulated check-in'));
    await tester.pumpAndSettle();
  }

  /// Answer buttons live in a scrollable column, so each one is brought into
  /// view before it is tapped. Without this a tap can land on whatever is
  /// painted at the computed offset.
  ///
  /// Bounded `pump` calls are used after the tap rather than `pumpAndSettle`:
  /// the final answer puts a progress spinner on screen, and `pumpAndSettle`
  /// never returns while an indeterminate indicator is animating.
  Future<void> tapAnswer(WidgetTester tester, String label) async {
    final finder = find.text(label);
    // The answer list is lazy, so the button may not exist in the tree yet.
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    // Bounded pumps rather than pumpAndSettle: the outcome screen shows an
    // indeterminate spinner, which never lets pumpAndSettle return. Several
    // short pumps let the real async submit chain complete.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('is clearly presented as a demo simulation', (tester) async {
    await pumpCheckin(tester, FakeApiClient());

    expect(find.text('DEMO SIMULATION'), findsOneWidget);
    expect(find.text('AI Wellness Check-in'), findsOneWidget);
    expect(find.text('Wellness Assistant'), findsWidgets);
    expect(find.text('Quick 2-minute check-in'), findsOneWidget);
    expect(
      find.text('Hello. This is your scheduled wellness check-in.'),
      findsOneWidget,
    );
    // It must never imply a real AI phone call.
    expect(
      find.textContaining('Simulated AI call · 4 questions'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('There is no real phone call'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('There is no real phone call'),
      findsOneWidget,
    );
  });

  testWidgets(
    'maps conversational answers onto the existing assessment contract',
    (tester) async {
      final api = FakeApiClient();
      await pumpCheckin(tester, api);

      // "Very stressed" -> stress 10

      await startCheckin(tester);

      expect(find.text('How are you feeling today?'), findsOneWidget);
      await tapAnswer(tester, 'Very stressed');
      await tester.pumpAndSettle();

      // "Very high" workload -> 10
      expect(
        find.text('How would you rate your current workload?'),
        findsOneWidget,
      );
      await tapAnswer(tester, 'Very high');
      await tester.pumpAndSettle();

      // "Not enough" rest -> 3 h rest / 3.5 h sleep
      expect(find.text('Have you had enough rest recently?'), findsOneWidget);
      await tapAnswer(tester, 'Not enough');
      await tester.pumpAndSettle();

      expect(
        find.text('Would you like a welfare officer to follow up?'),
        findsOneWidget,
      );
      await tapAnswer(tester, 'Yes');
      await tester.pumpAndSettle();

      // Completion screen.
      expect(find.text('Check-in completed'), findsOneWidget);
      expect(
        find.text('Your responses have been recorded for welfare assessment.'),
        findsOneWidget,
      );

      // The values shown are the ones that were mapped for the API.
      expect(find.text('10 / 10'), findsNWidgets(2));
      expect(find.text('3.0 h'), findsOneWidget);
      expect(find.text('3.5 h'), findsOneWidget);

      // The real backend prediction is what gets shown - not a local score.
      expect(find.text('Current Risk Assessment'), findsOneWidget);
      expect(find.text('HIGH'), findsWidgets);
      expect(find.text('Model score 0.70'), findsOneWidget);
    },
  );

  testWidgets('offers the full result screen with real factors', (tester) async {
    final api = FakeApiClient();
    await pumpCheckin(tester, api);


    await startCheckin(tester);

    await tapAnswer(tester, 'Stressed');
    await tester.pumpAndSettle();
    await tapAnswer(tester, 'Moderate');
    await tester.pumpAndSettle();
    await tapAnswer(tester, 'Mostly');
    await tester.pumpAndSettle();
    await tapAnswer(tester, 'No');
    await tester.pumpAndSettle();
    expect(
      find.text('See full result and factors'),
      findsOneWidget,
    );
    await tester.tap(find.text('See full result and factors'));
    await tester.pumpAndSettle();

    expect(find.byType(PredictionResultScreen), findsOneWidget);
    expect(find.text('Why this assessment?'), findsOneWidget);
    expect(
      find.text('Factors contributing toward higher risk'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows organizational information as simulated, not a real integration',
    (tester) async {
      final api = FakeApiClient()
        ..dutyRecords = [
          DutyRecord(
            id: 'r1',
            personnelKey: '11111111-1111-1111-1111-111111111111',
            recordDate: DateTime.utc(2026, 9, 10),
            dutyType: DutyType.deployment,
            dutyHours: 8,
            createdAt: DateTime.utc(2026, 9, 10),
            updatedAt: DateTime.utc(2026, 9, 10),
          ),
        ];
      await pumpCheckin(tester, api);

      expect(find.text('Organizational information'), findsOneWidget);
      expect(
        find.text('Source: Authorized organizational systems'),
        findsOneWidget,
      );
      expect(find.text('Prototype simulation'), findsOneWidget);
      // The personnel's real duty context is shown...
      expect(find.textContaining('Deployment'), findsOneWidget);
      // ...and the integration boundary is stated honestly.
      expect(
        find.textContaining('That integration is planned, not present'),
        findsOneWidget,
      );
    },
  );

  testWidgets('surfaces a backend submission failure without losing answers', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..submitAssessmentError = const ApiException(
        422,
        'Assessment data cannot be used for prediction',
      );
    await pumpCheckin(tester, api);


    await startCheckin(tester);

    await tapAnswer(tester, 'Good');
    await tester.pumpAndSettle();
    await tapAnswer(tester, 'Low');
    await tester.pumpAndSettle();
    await tapAnswer(tester, 'Yes');
    await tester.pumpAndSettle();
    await tapAnswer(tester, 'No');
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
