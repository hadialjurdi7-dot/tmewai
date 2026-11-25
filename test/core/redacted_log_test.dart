import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/logging/redacted_log.dart';

class _RecordingSink implements LogSink {
  final List<MapEntry<String, Map<String, Object?>>> events = [];

  @override
  void emit(String event, Map<String, Object?> fields) {
    events.add(MapEntry(event, Map<String, Object?>.of(fields)));
  }
}

class _ThrowingSink implements LogSink {
  @override
  void emit(String event, Map<String, Object?> fields) {
    throw StateError('sink is unavailable');
  }
}

void main() {
  test('event records its name and fields at info level', () {
    final sink = _RecordingSink();
    final log = RedactedLog(sink);

    log.event('import.started', {'platform': 'facebook', 'sourceKind': 'archive'});
    log.event('import.cancelled');

    expect(sink.events.map((entry) => entry.key), [
      'import.started',
      'import.cancelled',
    ]);
    expect(sink.events.first.value, {
      'level': 'info',
      'platform': 'facebook',
      'sourceKind': 'archive',
    });
    expect(sink.events.last.value, {'level': 'info'});
  });

  test('failure records the code and class name, never the message', () {
    final sink = _RecordingSink();
    final log = RedactedLog(sink);
    final error = StateError('could not read /home/user/exports/friend.zip');

    log.failure(
      'import.failed',
      code: 'archive_invalid',
      error: error,
      fields: {'phase': 'inspecting'},
    );

    final fields = sink.events.single.value;
    expect(fields['level'], 'error');
    expect(fields['code'], 'archive_invalid');
    expect(fields['phase'], 'inspecting');
    expect(fields['errorClass'], 'StateError');
    expect(fields.toString(), isNot(contains('/home/user')));
    expect(fields.toString(), isNot(contains('friend.zip')));
  });

  test('failure omits the class name when it has no error object', () {
    final sink = _RecordingSink();
    final log = RedactedLog(sink);

    log.failure('import.selection_failed', code: 'unknown_error');

    expect(sink.events.single.value, {
      'level': 'error',
      'code': 'unknown_error',
    });
  });

  test('a throwing sink never escapes into the caller', () {
    final log = RedactedLog(_ThrowingSink());

    expect(
      () => log.event('import.started', {'platform': 'facebook'}),
      returnsNormally,
    );
    expect(
      () => log.failure('import.failed', code: 'archive_invalid'),
      returnsNormally,
    );
  });
}
