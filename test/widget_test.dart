import 'package:flutter_test/flutter_test.dart';
import 'package:devcase_test/main.dart';

void main() {
  testWidgets('DevCaseApp smoke test', (WidgetTester tester) async {
    // Build DevCaseApp and trigger a frame.
    await tester.pumpWidget(const DevCaseApp());

    // Verify app renders DevCase title or login screen elements
    expect(find.text('DevCase'), findsWidgets);
  });
}
