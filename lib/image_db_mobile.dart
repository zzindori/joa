import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import 'db_factory.dart';

class ImageDB {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await openJoaDatabase();
    return _db!;
  }

  static Future<void> insert(String filename, Uint8List bytes) async {
    final db = await _database;
    await db.insert(
      'joa_images',
      {
        'filename': filename,
        'bytes': bytes,
        'created_at': DateTime.now().toIso8601String(),
        'saved_to_gallery': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> loadAll() async {
    final db = await _database;
    return db.query('joa_images', orderBy: 'created_at DESC');
  }

  static Future<int> count() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM joa_images');
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<void> delete(String filename) async {
    final db = await _database;
    await db.delete('joa_images', where: 'filename = ?', whereArgs: [filename]);
  }

  static Future<void> markSaved(String filename) async {
    final db = await _database;
    await db.update(
      'joa_images',
      {'saved_to_gallery': 1},
      where: 'filename = ?',
      whereArgs: [filename],
    );
  }

  // 갤러리 저장된 것 중 가장 오래된 것 우선, 없으면 미저장 중 가장 오래된 것
  static Future<Map<String, dynamic>?> oldestForDeletion() async {
    final db = await _database;
    final saved = await db.query(
      'joa_images',
      where: 'saved_to_gallery = 1',
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (saved.isNotEmpty) return saved.first;
    final all = await db.query(
      'joa_images',
      orderBy: 'created_at ASC',
      limit: 1,
    );
    return all.isNotEmpty ? all.first : null;
  }
}
