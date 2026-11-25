import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_data_agent/src/app/app.dart';
import 'package:personal_data_agent/src/app/demo_seed.dart';
import 'package:personal_data_agent/src/core/logging/startup_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Installed before anything else: a start that fails leaves evidence in
  // `startup.log` instead of an empty window.
  installStartupDiagnostics();
  runZonedGuarded(
    () {
      final container = ProviderContainer();
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const PersonalDataAgentApp(),
        ),
      );
      // Browser QA hook: `/?demo=fx` imports the bundled export so the archive
      // screens have rows to assert on. No-op everywhere else.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        startupTrace('first_frame');
        seedDemoArchiveIfRequested(container);
      });
    },
    (error, stack) => startupTrace('zone', error: error, stack: stack),
  );
}
