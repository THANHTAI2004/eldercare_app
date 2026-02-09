import 'package:flutter/material.dart';
import 'package:eldercare_app/src/app/app.dart';

void main() {
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const EldercareApp());
}
