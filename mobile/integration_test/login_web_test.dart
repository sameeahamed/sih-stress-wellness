import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sih_stress_wellness/core/api_client.dart';
import 'package:sih_stress_wellness/core/config.dart';
import 'package:sih_stress_wellness/core/token_store.dart';
import 'package:sih_stress_wellness/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real backend login lands on home screen', (tester) async {
    final store = SecureTokenStore();
    await store.delete();
    await tester.pumpWidget(
      SihStressWellnessApp(
        apiClient: ApiClient(baseUrl: AppConfig.apiBaseUrl),
        tokenStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personnel App'), findsOneWidget,
        reason: 'login screen should be visible');

    await tester.enterText(
        find.byType(TextFormField).at(0), 'seed_personnel_low');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'demo-password-123');
    await tester.tap(find.text('Sign in'));

    bool home = false;
    String? error;
    String? storedToken;
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      storedToken = await store.read();
      if (find.text('Personnel Home').evaluate().isNotEmpty) {
        home = true;
        break;
      }
      for (final e in find.textContaining('expired').evaluate()) {
        final t = (e.widget as Text).data;
        if (t != null && t.isNotEmpty) error = t;
      }
      for (final e in find.textContaining('error').evaluate()) {
        final t = (e.widget as Text).data;
        if (t != null && t.isNotEmpty) error = t;
      }
      if (error != null) break;
    }

    debugPrint('INTEGRATION_RESULT home=$home error=$error '
        'storedToken=${storedToken?.isNotEmpty ?? false}');
    expect(home, isTrue, reason: 'login failed: $error');
    expect(find.text('Personnel Home'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 3)));
}