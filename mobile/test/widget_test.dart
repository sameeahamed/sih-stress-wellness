import 'package:flutter_test/flutter_test.dart';

import 'package:sih_stress_wellness/main.dart';

void main() {
  testWidgets('Home screen renders app title', (WidgetTester tester) async {
    await tester.pumpWidget(const SihStressWellnessApp());

    expect(find.text('Stress & Welfare Monitoring'), findsOneWidget);
    expect(find.text('SIH 2026 Prototype'), findsOneWidget);
    expect(find.text('SYNTHETIC DEMO DATA'), findsOneWidget);
  });
}