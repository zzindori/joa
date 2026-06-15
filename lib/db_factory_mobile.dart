import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openJoaDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return openDatabase(
    p.join(dir.path, 'joa_images.db'),
    version: 1,
    onCreate: _createDb,
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
