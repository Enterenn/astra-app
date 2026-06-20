import 'package:astra_app/core/time/time_provider.dart';
import 'package:astra_app/data/repositories/step/step_aggregation_repository.dart';
import 'package:astra_app/data/repositories/step/step_ingestion_repository.dart';
import 'package:astra_app/data/services/csv_service.dart';
import 'package:sqflite/sqflite.dart';

/// Tuple of split step repositories sharing one [Database] connection.
class StepTestRepos {
  const StepTestRepos({
    required this.ingestion,
    required this.aggregation,
    required this.csv,
  });

  final StepIngestionRepository ingestion;
  final StepAggregationRepository aggregation;
  final CsvService csv;
}

/// Constructs ingestion, aggregation, and CSV services from the same [db].
class StepTestFixtures {
  static StepTestRepos create({
    required Database db,
    required TimeProvider clock,
    String databasePath = inMemoryDatabasePath,
  }) {
    return StepTestRepos(
      ingestion: StepIngestionRepository(db, databasePath: databasePath),
      aggregation: StepAggregationRepository(
        db,
        clock: clock,
        databasePath: databasePath,
      ),
      csv: CsvService(db, clock: clock, databasePath: databasePath),
    );
  }
}
