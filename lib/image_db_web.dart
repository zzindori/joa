import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';

class ImageDB {
  static const _boxName = 'joa_images_v2';
  static Box? _box;

  static Future<Box> get _store async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  static Future<void> insert(String filename, Uint8List bytes) async {
    final box = await _store;
    await box.put(filename, {
      'filename': filename,
      'bytes': bytes,
      'created_at': DateTime.now().toIso8601String(),
      'saved_to_gallery': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> loadAll() async {
    final box = await _store;
    final items = box.keys.cast<String>().map((k) {
      return Map<String, dynamic>.from(box.get(k) as Map);
    }).toList();
    items.sort((a, b) =>
        (b['created_at'] as String).compareTo(a['created_at'] as String));
    return items;
  }

  static Future<int> count() async {
    final box = await _store;
    return box.length;
  }

  static Future<void> delete(String filename) async {
    final box = await _store;
    await box.delete(filename);
  }

  static Future<void> markSaved(String filename) async {
    final box = await _store;
    final raw = box.get(filename);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    map['saved_to_gallery'] = 1;
    await box.put(filename, map);
  }

  static Future<Map<String, dynamic>?> oldestForDeletion() async {
    final box = await _store;
    if (box.isEmpty) return null;
    final items = await loadAll();
    items.sort((a, b) =>
        (a['created_at'] as String).compareTo(b['created_at'] as String));
    final saved = items.where((e) => (e['saved_to_gallery'] as int) == 1).toList();
    return saved.isNotEmpty ? saved.first : items.first;
  }
}
