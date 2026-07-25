import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Release-safe structured logs for overnight / field diagnosis.
///
/// Filter exported files with tag prefix: `[ASTRA:FIELD]`
const kFieldDiagnosticLogTag = '[ASTRA:FIELD]';

/// Daily log files older than this are deleted on write.
const kFieldLogRetentionDays = 5;

/// Inter-arrival gaps longer than this are logged as potential collection holes.
const kFieldLogGapThreshold = Duration(minutes: 5);

/// Disable at build time: `--dart-define=ASTRA_FIELD_LOG=false`
const bool _kFieldLogDefine = bool.fromEnvironment(
  'ASTRA_FIELD_LOG',
  defaultValue: true,
);

@visibleForTesting
bool fieldDiagnosticLogForceDisabled = false;

@visibleForTesting
bool fieldDiagnosticLogForceEnabled = false;

@visibleForTesting
FieldLogDirectoryProvider fieldLogDirectoryProvider = _defaultFieldLogDirectory;

typedef FieldLogDirectoryProvider = Future<String> Function();

bool get fieldDiagnosticLogEnabled =>
    (_kFieldLogDefine || fieldDiagnosticLogForceEnabled) &&
    !fieldDiagnosticLogForceDisabled;

final Map<String, DateTime> _lastLoggedAt = {};
Future<void> _writeChain = Future<void>.value();

void fieldDiagnosticLog(
  String phase,
  String message, {
  Map<String, Object?> details = const {},
  Duration minInterval = Duration.zero,
}) {
  if (!fieldDiagnosticLogEnabled) {
    return;
  }

  final throttleKey = '$phase::$message';
  if (minInterval > Duration.zero) {
    final last = _lastLoggedAt[throttleKey];
    final now = DateTime.now();
    if (last != null && now.difference(last) < minInterval) {
      return;
    }
    _lastLoggedAt[throttleKey] = now;
  }

  final detailText = details.isEmpty
      ? ''
      : ' ${details.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  final line =
      '${DateTime.now().toUtc().toIso8601String()} $phase: $message$detailText\n';

  if (kDebugMode) {
    debugPrint('$kFieldDiagnosticLogTag $phase: $message$detailText');
  }

  _writeChain = _writeChain
      .then((_) => _appendLine(line))
      .catchError((Object error) {
        if (kDebugMode) {
          debugPrint('$kFieldDiagnosticLogTag write failed: $error');
        }
      });
}

Future<String> _defaultFieldLogDirectory() async {
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'field_logs');
}

Future<void> _appendLine(String line) async {
  final dirPath = await fieldLogDirectoryProvider();
  final dir = Directory(dirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final day = _formatUtcDay(DateTime.now().toUtc());
  final file = File(p.join(dirPath, 'field_$day.log'));
  await file.writeAsString(line, mode: FileMode.append, flush: true);
  await _pruneOldLogs(dir);
}

Future<void> _pruneOldLogs(Directory dir) async {
  final cutoff = DateTime.now().toUtc().subtract(
    const Duration(days: kFieldLogRetentionDays),
  );
  await for (final entity in dir.list()) {
    if (entity is! File) {
      continue;
    }
    final name = p.basename(entity.path);
    if (!name.startsWith('field_') || !name.endsWith('.log')) {
      continue;
    }
    final dayStr = name.substring(6, name.length - 4);
    final fileDay = DateTime.tryParse('${dayStr}T00:00:00.000Z');
    if (fileDay != null && fileDay.isBefore(cutoff)) {
      await entity.delete();
    }
  }
}

String _formatUtcDay(DateTime utc) {
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Builds a single text file from retained daily logs for export.
Future<String> prepareFieldDiagnosticLogExport({
  required String outputDirectory,
  FieldLogDirectoryProvider? directoryProvider,
}) async {
  final dirPath = await (directoryProvider ?? fieldLogDirectoryProvider)();
  final dir = Directory(dirPath);
  final buffer = StringBuffer('$kFieldDiagnosticLogTag export\n');

  if (await dir.exists()) {
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (file) => p.basename(file.path).startsWith('field_'),
            )
            .toList()
          ..sort(
            (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
          );

    for (final file in files) {
      buffer.writeln('--- ${p.basename(file.path)} ---');
      buffer.write(await file.readAsString());
      if (!buffer.toString().endsWith('\n')) {
        buffer.writeln();
      }
    }
  }

  if (buffer.length == kFieldDiagnosticLogTag.length + 8) {
    buffer.writeln('(no events recorded yet)');
  }

  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final exportPath = p.join(outputDirectory, 'astra_field_log_$stamp.txt');
  await File(exportPath).writeAsString(buffer.toString());
  return exportPath;
}

/// Waits for queued disk writes — call before exporting logs.
Future<void> flushFieldDiagnosticLog() => _writeChain;

@visibleForTesting
Future<void> flushFieldDiagnosticLogForTests() => flushFieldDiagnosticLog();

@visibleForTesting
void resetFieldDiagnosticLogForTests() {
  _lastLoggedAt.clear();
  _writeChain = Future<void>.value();
  fieldLogDirectoryProvider = _defaultFieldLogDirectory;
}
