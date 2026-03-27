import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:eldercare_app/src/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerDesktopPlugins();
  await dotenv.load(fileName: '.env');

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const EldercareApp());
}

void _registerDesktopPlugins() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;

  PathProviderWindows.registerWith();
  SharedPreferencesWindows.registerWith();
}
