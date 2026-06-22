import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

abstract class StepIngestionRepositoryContract {
  Future<void> purge({
    @visibleForTesting Future<void> Function(Transaction txn)? testHookAfterDeleteSamples,
  });
}
