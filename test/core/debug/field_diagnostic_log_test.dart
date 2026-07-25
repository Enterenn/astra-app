@Tags(['critical'])
library;

import 'dart:io';

import 'package:astra_app/core/debug/field_diagnostic_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory logDir;

  setUp(() async {
    resetFieldDiagnosticLogForTests();
    fieldDiagnosticLogForceDisabled = false;
    fieldDiagnosticLogForceEnabled = true;
    logDir = await Directory.systemTemp.createTemp('astra_field_log_');
    fieldLogDirectoryProvider = () async => logDir.path;
  });

  tearDown(() async {
    resetFieldDiagnosticLogForTests();
    fieldDiagnosticLogForceEnabled = false;
    if (await logDir.exists()) {
      await logDir.delete(recursive: true);
    }
  });

  test('appends daily log file when enabled', () async {
    fieldDiagnosticLog('fgs', 'start OK', details: {'active': true});

    await flushFieldDiagnosticLogForTests();

    final day = DateTime.now().toUtc();
    final dayName =
        'field_${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}.log';
    final file = File(p.join(logDir.path, dayName));
    expect(await file.exists(), isTrue);
    final contents = await file.readAsString();
    expect(contents, contains('fgs: start OK active=true'));
  });

  test('does not write when disabled', () async {
    fieldDiagnosticLogForceEnabled = false;
    fieldDiagnosticLogForceDisabled = true;

    fieldDiagnosticLog('fgs', 'start OK');
    await flushFieldDiagnosticLogForTests();

    expect(await Directory(logDir.path).list().length, 0);
  });

  test('prepareFieldDiagnosticLogExport concatenates retained files', () async {
    await File(p.join(logDir.path, 'field_2026-07-24.log')).writeAsString(
      '2026-07-24T10:00:00.000Z wm: task OK\n',
    );
    await File(p.join(logDir.path, 'field_2026-07-25.log')).writeAsString(
      '2026-07-25T08:00:00.000Z fgs: start OK\n',
    );

    final exportDir = await Directory.systemTemp.createTemp('astra_field_export_');
    try {
      final exportPath = await prepareFieldDiagnosticLogExport(
        outputDirectory: exportDir.path,
        directoryProvider: () async => logDir.path,
      );
      final exportContents = await File(exportPath).readAsString();
      expect(exportContents, contains('field_2026-07-24.log'));
      expect(exportContents, contains('wm: task OK'));
      expect(exportContents, contains('fgs: start OK'));
    } finally {
      await exportDir.delete(recursive: true);
    }
  });

  test('prunes logs older than retention window', () async {
    await File(p.join(logDir.path, 'field_2026-07-01.log')).writeAsString(
      'old\n',
    );

    fieldDiagnosticLog('app', 'lifecycle RESUMED');
    await flushFieldDiagnosticLogForTests();

    expect(await File(p.join(logDir.path, 'field_2026-07-01.log')).exists(), isFalse);
  });
}
