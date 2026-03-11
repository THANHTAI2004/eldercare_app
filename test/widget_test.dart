import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_app/src/app/app.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const EldercareApp());
    expect(find.byType(DevicePage), findsOneWidget);
  });
}
