import 'package:flutter_test/flutter_test.dart';
import 'package:tkoi_shop/main.dart';

void main() {
  testWidgets('startup error screen is readable', (tester) async {
    await tester.pumpWidget(
      const StartupErrorApp(message: 'Test connection error'),
    );

    expect(find.text('Tkoi could not connect'), findsOneWidget);
    expect(find.text('Test connection error'), findsOneWidget);
  });
}
