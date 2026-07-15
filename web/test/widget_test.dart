import 'package:flutter_test/flutter_test.dart';
import 'package:fuelsense_web/main.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const FuelSenseWebApp());
    expect(find.byType(FuelSenseWebApp), findsOneWidget);
  });
}
