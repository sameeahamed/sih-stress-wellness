import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/models.dart';
import 'package:sih_stress_wellness/features/history/history_screen.dart';

import 'fake_api.dart';

void main() {
  Future<void> pumpHistory(WidgetTester tester, FakeApiClient api) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final harness = await authenticatedController(api: api);
    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(controller: harness.controller)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows an empty state with a way to start when there is no data',
    (tester) async {
      await pumpHistory(tester, FakeApiClient());

      expect(
        find.textContaining('You have not completed a wellness check-in yet'),
        findsOneWidget,
      );
      expect(find.text('Start a check-in'), findsOneWidget);
    },
  );

  testWidgets('lists results on a timeline with risk level and dates', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..predictions = [
        Prediction(
          id: 'p1',
          personnelKey: '11111111-1111-1111-1111-111111111111',
          assessmentId: 'a1',
          riskLevel: RiskLevel.high,
          probabilityLow: 0.1,
          probabilityMedium: 0.2,
          probabilityHigh: 0.7,
          contributingFactors: const ['elevated weekly duty hours'],
          modelVersion: 'v1',
          reviewStatus: ReviewStatus.pending,
          createdAt: DateTime.utc(2026, 9, 20, 10),
        ),
      ];
    await pumpHistory(tester, api);

    expect(find.text('Your results'), findsOneWidget);
    expect(find.text('HIGH  70%'), findsOneWidget);
    expect(find.textContaining('2026-09-20'), findsWidgets);
    // Plain-language meaning is shown without tapping.
    expect(find.textContaining('would benefit from support'), findsOneWidget);
    // Last-updated line.
    expect(find.textContaining('Last updated'), findsOneWidget);
  });

  testWidgets('expanding a result reveals its contributing model factors', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..predictions = [
        Prediction(
          id: 'p1',
          personnelKey: '11111111-1111-1111-1111-111111111111',
          assessmentId: 'a1',
          riskLevel: RiskLevel.high,
          probabilityLow: 0.1,
          probabilityMedium: 0.2,
          probabilityHigh: 0.7,
          contributingFactors: const ['elevated weekly duty hours'],
          modelVersion: 'v1',
          reviewStatus: ReviewStatus.pending,
          createdAt: DateTime.utc(2026, 9, 20, 10),
        ),
      ];
    await pumpHistory(tester, api);

    expect(find.text('Contributing model factors'), findsNothing);

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('Contributing model factors'), findsOneWidget);
    expect(find.text('elevated weekly duty hours'), findsOneWidget);
    expect(
      find.text('These are model factors, not medical causes.'),
      findsOneWidget,
    );
    expect(find.text('Version v1'), findsOneWidget);
  });

  testWidgets('groups check-ins that have no result yet', (tester) async {
    final api = FakeApiClient()
      ..assessments = [
        WellnessAssessment(
          id: 'a1',
          personnelKey: '11111111-1111-1111-1111-111111111111',
          stressLevelSelfReport: 5,
          restHours7d: 7,
          sleepHours7d: 6,
          workloadScore: 5,
          submittedAt: DateTime.utc(2026, 9, 19, 9),
          createdAt: DateTime.utc(2026, 9, 19, 9),
        ),
      ];
    await pumpHistory(tester, api);

    expect(find.text('Check-ins without a result'), findsOneWidget);
    expect(find.textContaining('Self-reported stress 5/10'), findsOneWidget);
  });
}
