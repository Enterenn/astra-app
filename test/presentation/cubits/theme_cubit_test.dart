import 'package:astra_app/presentation/cubits/theme_cubit.dart';
import 'package:astra_app/presentation/cubits/theme_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ThemeCubit defaults to system preference and ThemeMode', () {
    final cubit = ThemeCubit();

    expect(cubit.state.preference, AstraThemePreference.system);
    expect(cubit.state.materialThemeMode, ThemeMode.system);

    cubit.close();
  });
}
