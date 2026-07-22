// Basic smoke test: the app boots to the login screen and shows the two
// mock auth buttons.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eventixar/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EventixarApp()));
    await tester.pumpAndSettle();

    expect(find.text('Eventixar'), findsWidgets);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con Apple'), findsOneWidget);
  });
}
