// ignore: avoid_web_libraries_in_flutter
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openJoaDatabase() async {
  databaseFactory = databaseFactoryFfiWeb;
  return databaseFactory.openDatabase(
    'joa_images.db',
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: _createDb,
    ),
  );
}

Future<void> _createDb(Database db, int version) async {
  await db.execute('''
    CREATE TABLE joa_images (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      filename TEXT UNIQUE NOT NULL,
      bytes BLOB NOT NULL,
      created_at TEXT NOT NULL,
      saved_to_gallery INTEGER NOT NULL DEFAULT 0
    )
  ''');
}
