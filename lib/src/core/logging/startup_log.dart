import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Name of the local startup trace, written beside the workspace database.
const String startupLogFileName = 'startup.log';

/// Appends one line to `startup.log` in the application support folder.
///
/// Fire and forget on purpose: a diagnostic must never delay a start or throw
/// into the caller, because it runs on the path that is already failing. The
/// event name, the message and the stack are written verbatim — this file never
/// leaves the machine, and a start that produces no window cannot be debugged
/// from a redacted code alone.
void startupTrace(String event, {Object? error, StackTrace? stack}) {
  unawaited(() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File(p.join(directory.path, startupLogFileName));
      final stamp = DateTime.now().toUtc().toIso8601String();
      final line = StringBuffer('$stamp $event\n');
      if (error != null) line.write('  error: $error\n');
      if (stack != null) line.write('  stack: $stack\n');
      await file.writeAsString(
        line.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } on Object {
      // Best effort: the app's own start matters more than the trace.
    }
  }());
}

/// Routes every error Flutter reports into [startupTrace].
///
/// Without this a release build that fails before the first frame shows an
/// empty window and nothing else, which is indistinguishable from a hang.
void installStartupDiagnostics() {
  startupTrace('boot');
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    startupTrace(
      'flutter_error',
      error: details.exceptionAsString(),
      stack: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    startupTrace('uncaught', error: error, stack: stack);
    // Handled: keep the window alive so the trace can be read, instead of
    // letting one failed future take the whole start down.
    return true;
  };
}
