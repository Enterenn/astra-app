import 'dart:async';
import 'dart:io';

import 'helpers/sqflite_test_helper.dart';

/// Global test bootstrap for sqflite FFI on desktop/VM.
///
/// On Windows, [sqfliteFfiInit] opens SQLite in the main isolate before any
/// test file runs. Together with `hooks.user_defines.sqlite3` using
/// `winsqlite3.dll`, this avoids native-asset copy/lock issues on sqlite3.dll.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isWindows) {
    initSqfliteFfiForTests();
  }
  await testMain();
}
