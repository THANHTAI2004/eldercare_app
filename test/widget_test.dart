import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eldercare_app/src/app/app.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const EldercareApp());
    expect(find.byType(DevicePage), findsOneWidget);
  });
}
