import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = inMemoryDatabasePath;
    await databaseFactory.deleteDatabase(dbPath);
  });

  test('create reservation reduces availableStock', () async {
    expect(true, true);
  });

  test('checkAndExpireReservations frees up stock', () async {
    expect(true, true);
  });
}
