import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/main.dart';

void main() {
  testWidgets('App smoke test — StrataApp renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
    await tester.pump();
    // Simply verify the widget tree builds without throwing.
    expect(tester.takeException(), isNull);
  });
}
