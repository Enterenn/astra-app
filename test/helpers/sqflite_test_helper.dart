import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initializes sqflite FFI for VM/desktop unit tests.
///
/// Call from `setUpAll` in test files. Each test file should [Database.close]
/// in `tearDown` so the native sqlite3.dll can be released before the next run.
void initSqfliteFfiForTests() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<void> setUpSqfliteFfi() async {
  initSqfliteFfiForTests();
}
