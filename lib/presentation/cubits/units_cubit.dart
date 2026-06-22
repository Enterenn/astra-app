import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/display_unit_preferences.dart';
import '../../data/contracts/user_settings_repository_contract.dart';
import 'units_state.dart';

class UnitsCubit extends Cubit<UnitsState> {
  UnitsCubit({
    required this.userSettings,
    DistanceDisplayUnit initialDistanceUnit = DistanceDisplayUnit.metric,
    WeightDisplayUnit initialWeightUnit = WeightDisplayUnit.kg,
    HeightDisplayUnit initialHeightUnit = HeightDisplayUnit.cm,
  }) : super(
         UnitsState(
           distanceUnit: initialDistanceUnit,
           weightUnit: initialWeightUnit,
           heightUnit: initialHeightUnit,
         ),
       );

  final UserSettingsRepositoryContract userSettings;

  Future<void>? _setInFlight;

  Future<bool> setDistanceUnit(DistanceDisplayUnit unit) async {
    if (state.distanceUnit == unit) {
      return false;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    var success = false;
    operation = () async {
      success = await _persistDistanceAndEmit(unit, waitFor);
    }();
    _setInFlight = operation;
    try {
      await operation;
      return success;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<bool> setWeightUnit(WeightDisplayUnit unit) async {
    if (state.weightUnit == unit) {
      return false;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    var success = false;
    operation = () async {
      success = await _persistWeightAndEmit(unit, waitFor);
    }();
    _setInFlight = operation;
    try {
      await operation;
      return success;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<bool> setHeightUnit(HeightDisplayUnit unit) async {
    if (state.heightUnit == unit) {
      return false;
    }

    final waitFor = _setInFlight;
    late final Future<void> operation;
    var success = false;
    operation = () async {
      success = await _persistHeightAndEmit(unit, waitFor);
    }();
    _setInFlight = operation;
    try {
      await operation;
      return success;
    } finally {
      if (_setInFlight == operation) {
        _setInFlight = null;
      }
    }
  }

  Future<bool> _persistDistanceAndEmit(
    DistanceDisplayUnit unit,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.distanceUnit == unit) {
      return false;
    }
    try {
      await userSettings.setDistanceDisplayUnit(unit);
    } catch (_) {
      return false;
    }
    if (isClosed || state.distanceUnit == unit) {
      return false;
    }
    emit(
      UnitsState(
        distanceUnit: unit,
        weightUnit: state.weightUnit,
        heightUnit: state.heightUnit,
      ),
    );
    return true;
  }

  Future<bool> _persistWeightAndEmit(
    WeightDisplayUnit unit,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.weightUnit == unit) {
      return false;
    }
    try {
      await userSettings.setWeightDisplayUnit(unit);
    } catch (_) {
      return false;
    }
    if (isClosed || state.weightUnit == unit) {
      return false;
    }
    emit(
      UnitsState(
        distanceUnit: state.distanceUnit,
        weightUnit: unit,
        heightUnit: state.heightUnit,
      ),
    );
    return true;
  }

  Future<bool> _persistHeightAndEmit(
    HeightDisplayUnit unit,
    Future<void>? waitFor,
  ) async {
    if (waitFor != null) {
      await waitFor;
    }
    if (isClosed || state.heightUnit == unit) {
      return false;
    }
    try {
      await userSettings.setHeightDisplayUnit(unit);
    } catch (_) {
      return false;
    }
    if (isClosed || state.heightUnit == unit) {
      return false;
    }
    emit(
      UnitsState(
        distanceUnit: state.distanceUnit,
        weightUnit: state.weightUnit,
        heightUnit: unit,
      ),
    );
    return true;
  }
}
