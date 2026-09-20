import 'package:flutter_test/flutter_test.dart';

import 'package:sih_stress_wellness/core/token_store.dart';
import 'package:sih_stress_wellness/main.dart';

import 'fake_api.dart';

void main() {
  testWidgets('app boots into the login screen without a stored session',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      SihStressWellnessApp(
        apiClient: FakeApiClient(),
        tokenStore: InMemoryTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personnel App'), findsOneWidget);
    expect(find.text('Stress & Welfare Monitoring'), findsNothing);
  });
}