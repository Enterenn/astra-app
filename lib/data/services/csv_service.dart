import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/time/local_day_formatter.dart';
import '../../core/time/time_provider.dart';
import '../contracts/csv_service_contract.dart';
import '../csv/timeseries_csv_codec.dart';
import '../models/import_result.dart';
import '../models/normalized_step_bucket.dart';
import '../models/timeseries_sample_model.dart';
import '../repositories/step/_step_repository_session.dart';

class CsvService implements CsvServiceContract {
  CsvService(
    Object sessionOrDatabase, {
    required this.clock,
    String databasePath = inMemoryDatabasePath,
  }) : _session = StepRepositorySession(
         sessionOrDatabase,
         databasePath: databasePath,
       );

  final StepRepositorySession _session;
  final TimeProvider clock;

  /// Exports all step samples to an OW-aligned CSV file (FR-19).
  ///
  /// Writes to [outputDirectory] with filename `astra-export-{yyyy-MM-dd}.csv`
  /// using the local calendar date from [clock]. Returns the absolute file path.
  /// Empty databases produce a header-only CSV.
  @override
  Future<String> exportCsv({required String outputDirectory}) async {
    // Yield so synchronous IO errors surface through the returned Future.
    await Future<void>.value();

    final dateStr = formatLocalDayIso(clock.snapshot());
    final filePath = p.join(outputDirectory, 'astra-export-$dateStr.csv');
    final file = File(filePath);
    final sink = file.openWrite();
    var succeeded = false;

    try {
      sink.writeln(TimeseriesCsvCodec.headerRow);

      const batchSize = 500;
      String? afterStartTime;
      String? afterId;
      while (true) {
        final rows = await _session.run(
          (db) => db.query(
            'timeseries_samples',
            where: afterStartTime == null
                ? 'type = ?'
                : 'type = ? AND (start_time > ? OR (start_time = ? AND id > ?))',
            whereArgs: afterStartTime == null
                ? [kStepSampleType]
                : [
                    kStepSampleType,
                    afterStartTime,
                    afterStartTime,
                    afterId,
                  ],
            orderBy: 'start_time ASC, id ASC',
            limit: batchSize,
          ),
        );

        if (rows.isEmpty) {
          break;
        }

        for (final row in rows) {
          final sample = TimeseriesSampleModel.fromMap(row);
          sink.writeln(TimeseriesCsvCodec.serializeRow(sample));
        }

        final lastRow = rows.last;
        afterStartTime = lastRow['start_time']! as String;
        afterId = lastRow['id']! as String;
        if (rows.length < batchSize) {
          break;
        }
      }
      succeeded = true;
    } finally {
      await sink.close();
      if (!succeeded && file.existsSync()) {
        await file.delete();
      }
    }

    return file.absolute.path;
  }

  /// Imports OW-aligned CSV rows in a single transaction (FR-30, D-16/D-24).
  ///
  /// Validates the entire file before any write. Merge-only: existing rows are
  /// not deleted; duplicate `id` or bucket identity increments [ImportResult.skippedCount].
  Future<ImportResult> importCsv({required String filePath}) async {
    await Future<void>.value();
    final samples = await TimeseriesCsvCodec.parseImportFile(filePath);
    return importSamples(samples);
  }

  /// Persists pre-validated samples in a single transaction (used after parse/confirm).
  @override
  Future<ImportResult> importSamples(List<TimeseriesSampleModel> samples) async {
    if (samples.isEmpty) {
      return const ImportResult(
        totalRowsInFile: 0,
        insertedCount: 0,
        skippedCount: 0,
      );
    }

    var insertedCount = 0;
    var skippedCount = 0;

    await _session.run(
      (db) => db.transaction((txn) async {
        for (final sample in samples) {
          final rowId = await txn.insert(
            'timeseries_samples',
            sample.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (rowId == 0) {
            skippedCount++;
          } else {
            insertedCount++;
          }
        }
      }),
    );

    return ImportResult(
      totalRowsInFile: samples.length,
      insertedCount: insertedCount,
      skippedCount: skippedCount,
    );
  }
}
