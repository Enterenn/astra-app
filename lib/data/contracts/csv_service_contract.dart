import '../models/import_result.dart';
import '../models/timeseries_sample_model.dart';

abstract class CsvServiceContract {
  Future<String> exportCsv({required String outputDirectory});

  Future<ImportResult> importSamples(List<TimeseriesSampleModel> samples);
}
