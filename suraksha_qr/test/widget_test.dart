// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suraksha_qr/main.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SurakshaQRApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Splash'), findsOneWidget);
  });
}