import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sih_stress_wellness/core/api_client.dart';
import 'package:sih_stress_wellness/core/session.dart';
import 'package:sih_stress_wellness/features/duty/duty_record_form_screen.dart';
import 'package:sih_stress_wellness/features/duty/duty_result_screen.dart';

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
      MaterialApp(home: DutyRecordFormScreen(controller: harness.controller)),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('requires both clock times when using clock-time mode',
      (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Submit duty record'));
    await tester.pumpAndSettle();

    expect(
      find.text('Set both a start and an end time (or use hours instead).'),
      findsOneWidget,
    );
    expect(find.byType(DutyRecordFormScreen), findsOneWidget);
  });

  testWidgets('accepts self-reported hours and submits (hours mode)',
      (tester) async {
    final api = FakeApiClient();
    await pumpForm(tester, api: api);

    await tester.tap(find.text('Hours'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '8');
    await tester.tap(find.text('Submit duty record'));
    await tester.pumpAndSettle();

    expect(find.byType(DutyResultScreen), findsOneWidget);
    expect(find.text('Duty record saved'), findsOneWidget);
    expect(find.textContaining('hours'), findsWidgets);
  });

  testWidgets('rejects invalid self-reported hours', (tester) async {
    await pumpForm(tester);

    await tester.tap(find.text('Hours'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '25');
    await tester.tap(find.text('Submit duty record'));
    await tester.pumpAndSettle();

    expect(find.text('Must be greater than 0 and at most 24'), findsOneWidget);
    expect(find.byType(DutyRecordFormScreen), findsOneWidget);
  });

  testWidgets('shows a backend error inline', (tester) async {
    final api = FakeApiClient()
      ..submitDutyRecordError = const ApiException(422, 'record_date cannot be in the future');
    await pumpForm(tester, api: api);

    await tester.tap(find.text('Hours'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '8');
    await tester.tap(find.text('Submit duty record'));
    await tester.pumpAndSettle();

    expect(find.text('record_date cannot be in the future'), findsOneWidget);
    expect(find.byType(DutyRecordFormScreen), findsOneWidget);
  });
}