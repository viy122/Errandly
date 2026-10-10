import 'dart:async';

import 'package:flutter/material.dart';

import 'data/errand_api.dart';
import 'state/errand_store.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const demoOnly = bool.fromEnvironment('DEMO_ONLY');
  final store = demoOnly
      ? ErrandStore()
      : ErrandStore.mysql(
          ErrandApi(
            url: const String.fromEnvironment(
              'API_URL',
              defaultValue: 'http://127.0.0.1/errandly/api/index.php',
            ),
          ),
        );
  runApp(ErrandlyApp(store: store, showIntro: true));
  unawaited(store.initialize());
}
