import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/models.dart';
import 'package:sih_stress_wellness/features/history/history_screen.dart';

import 'fake_api.dart';

void main() {
  Future<void> pumpHistory(
    WidgetTester tester,
    FakeApiClient api,
  ) async {
    final harness = await authenticatedController(api: api);
    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(controller: harness.controller)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state when the personnel has no records',
      (tester) async {
    await pumpHistory(tester, FakeApiClient());

    expect(
      find.text('No records yet. Submit a wellness assessment to get started.'),
      findsOneWidget,
    );
  });

  testWidgets('lists the personnel predictions with risk and dates',
      (tester) async {
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

    expect(find.text('Predictions'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.textContaining('Model v1'), findsWidgets);
    expect(find.textContaining('2026-09-20'), findsWidgets);
  });

  testWidgets('lists assessments that have no prediction yet', (tester) async {
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

    expect(find.text('Assessments without a prediction'), findsOneWidget);
    expect(find.textContaining('Stress report 5/10'), findsOneWidget);
  });
}