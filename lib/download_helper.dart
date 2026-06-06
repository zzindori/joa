import 'dart:typed_data';

import 'download_stub.dart'
    if (dart.library.html) 'download_web.dart'
    if (dart.library.io) 'download_mobile.dart';

Future<String?> saveImageToDevice(Uint8List? bytes, String? imageUrl, String filename) =>
    saveImageImpl(bytes, imageUrl, filename);
