import 'dart:typed_data';

import 'package:gal/gal.dart';

Future<String?> saveImageImpl(Uint8List? bytes, String? imageUrl, String filename) async {
  if (bytes == null) return '저장할 이미지가 없습니다.';
  try {
    await Gal.putImageBytes(bytes);
    return null;
  } catch (e) {
    return e.toString();
  }
}
