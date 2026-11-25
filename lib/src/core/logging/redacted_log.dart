import 'dart:convert';
import 'dart:developer' as developer;

/// A sink for content-free, structured log events.
///
/// An event is one stable name plus scalar fields, so an operator can filter
/// on the name and read the values it carries. The redaction rule binds every
/// sink: only a catalog code, an archive-relative path, a phase, a count or a
/// class name may reach it. A host path, file content, a credential or an
/// exception message never does (see `CodedException`).
abstract interface class LogSink {
  void emit(String event, Map<String, Object?> fields);
}

/// The default sink: one JSON line per event on the Dart developer log.
///
/// Each record shows in `flutter run` output and the DevTools Logging view,
/// which is where an operator reads the import pipeline during an issue. The
/// line is a single event object, so it stays one queryable record.
class DeveloperLogSink implements LogSink {
  const DeveloperLogSink();

  @override
  void emit(String event, Map<String, Object?> fields) {
    developer.log(
      jsonEncode(<String, Object?>{'event': event, ...fields}),
      name: 'tmewai',
    );
  }
}

/// Records content-free events for the import and workspace pipelines.
///
/// This is the repository's redacted logging seam: one wide event per
/// operation, with dynamic values in fields and a constant event name, so
/// clustering and filtering work. Pass a [LogSink] to capture events in a
/// test. Every call is best effort: a sink that throws never changes the
/// result of the operation it records.
class RedactedLog {
  const RedactedLog([this.sink = const DeveloperLogSink()]);

  /// Where each event goes. The default writes to the Dart developer log.
  final LogSink sink;

  /// Records the successful event [name] with [fields].
  void event(String name, [Map<String, Object?> fields = const {}]) {
    if (fields.isEmpty) {
      _emit(name, const {'level': 'info'});
      return;
    }
    _emit(name, <String, Object?>{'level': 'info', ...fields});
  }

  /// Records the failure event [name] with its catalog-safe [code].
  ///
  /// Only [code] and, for an unexpected error, the error's class name cross
  /// into the log. The exception message can carry a host path or content, so
  /// it is never recorded.
  void failure(
    String name, {
    required String code,
    Object? error,
    Map<String, Object?> fields = const {},
  }) {
    _emit(name, <String, Object?>{
      'level': 'error',
      ...fields,
      'code': code,
      if (error != null) 'errorClass': error.runtimeType.toString(),
    });
  }

  /// Sends one record to the sink, best effort.
  ///
  /// Logging must never change the result of the operation it records. A sink
  /// that throws is contained here and the record is dropped, because the
  /// alternative, letting the error escape, makes a failed log line look like a
  /// failed import.
  void _emit(String name, Map<String, Object?> fields) {
    try {
      sink.emit(name, fields);
    } on Object {
      // Dropped on purpose: a failing sink must not fail the import.
    }
  }
}
