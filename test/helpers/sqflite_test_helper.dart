import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initializes sqflite FFI for VM/desktop unit tests.
void initSqfliteFfiForTests() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<void> setUpSqfliteFfi() async {
  initSqfliteFfiForTests();
}
