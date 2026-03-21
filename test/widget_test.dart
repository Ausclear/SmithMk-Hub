import 'package:flutter_test/flutter_test.dart';
import 'package:smithmk_hub/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const SmithMkApp());
    expect(find.text('SmithMk'), findsOneWidget);
  });
}
