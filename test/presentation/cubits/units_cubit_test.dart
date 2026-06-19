import 'package:astra_app/core/constants/display_unit_preferences.dart';
import 'package:astra_app/core/database/app_database.dart';
import 'package:astra_app/data/repositories/user_settings_repository.dart';
import 'package:astra_app/presentation/cubits/units_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/sqflite_test_helper.dart';

class _ThrowingDistanceSettingsRepository extends UserSettingsRepository {
  _ThrowingDistanceSettingsRepository(Database db) : super(db);

  @override
  Future<void> setDistanceDisplayUnit(DistanceDisplayUnit unit) async {
    throw StateError('write failed');
  }
}

void main() {
  setUpAll(() async {
    await setUpSqfliteFfi();
  });

  group('UnitsCubit', () {
    late Database db;
    late UserSettingsRepository repository;

    setUp(() async {
      db = await openAstraDatabase(databasePath: inMemoryDatabasePath);
      repository = UserSettingsRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('defaults to metric distance, kg weight, and cm height', () {
      final cubit = UnitsCubit(userSettings: repository);

      expect(cubit.state.distanceUnit, DistanceDisplayUnit.metric);
      expect(cubit.state.weightUnit, WeightDisplayUnit.kg);
      expect(cubit.state.heightUnit, HeightDisplayUnit.cm);

      cubit.close();
    });

    test('setDistanceUnit persists and emits', () async {
      final cubit = UnitsCubit(userSettings: repository);

      expect(await cubit.setDistanceUnit(DistanceDisplayUnit.imperial), isTrue);
      expect(cubit.state.distanceUnit, DistanceDisplayUnit.imperial);
      expect(
        await repository.getDistanceDisplayUnit(),
        DistanceDisplayUnit.imperial,
      );

      await cubit.close();
    });

    test('setWeightUnit persists and emits', () async {
      final cubit = UnitsCubit(userSettings: repository);

      expect(await cubit.setWeightUnit(WeightDisplayUnit.lb), isTrue);
      expect(cubit.state.weightUnit, WeightDisplayUnit.lb);
      expect(await repository.getWeightDisplayUnit(), WeightDisplayUnit.lb);

      await cubit.close();
    });

    test('setHeightUnit persists and emits', () async {
      final cubit = UnitsCubit(userSettings: repository);

      expect(await cubit.setHeightUnit(HeightDisplayUnit.ftIn), isTrue);
      expect(cubit.state.heightUnit, HeightDisplayUnit.ftIn);
      expect(await repository.getHeightDisplayUnit(), HeightDisplayUnit.ftIn);

      await cubit.close();
    });

    test('setters no-op when value unchanged', () async {
      final cubit = UnitsCubit(
        userSettings: repository,
        initialDistanceUnit: DistanceDisplayUnit.metric,
      );
      await repository.setDistanceDisplayUnit(DistanceDisplayUnit.imperial);

      expect(await cubit.setDistanceUnit(DistanceDisplayUnit.metric), isFalse);
      expect(cubit.state.distanceUnit, DistanceDisplayUnit.metric);
      expect(
        await repository.getDistanceDisplayUnit(),
        DistanceDisplayUnit.imperial,
      );

      await cubit.close();
    });

    test('failed write leaves state unchanged', () async {
      final cubit = UnitsCubit(
        userSettings: _ThrowingDistanceSettingsRepository(db),
      );

      expect(await cubit.setDistanceUnit(DistanceDisplayUnit.imperial), isFalse);
      expect(cubit.state.distanceUnit, DistanceDisplayUnit.metric);

      await cubit.close();
    });

    test('rapid distance changes end on last value in DB and state', () async {
      final cubit = UnitsCubit(userSettings: repository);

      await Future.wait([
        cubit.setDistanceUnit(DistanceDisplayUnit.imperial),
        cubit.setDistanceUnit(DistanceDisplayUnit.metric),
        cubit.setDistanceUnit(DistanceDisplayUnit.imperial),
      ]);

      expect(cubit.state.distanceUnit, DistanceDisplayUnit.imperial);
      expect(
        await repository.getDistanceDisplayUnit(),
        DistanceDisplayUnit.imperial,
      );

      await cubit.close();
    });
  });
}
