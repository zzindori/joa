// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> saveImageImpl(Uint8List? bytes, String? imageUrl, String filename) async {
  if (imageUrl != null) {
    html.window.open(imageUrl, '_blank');
    return null;
  }
  if (bytes != null) {
    final blob = html.Blob([bytes], 'image/jpeg');
    final url = html.Url.createObjectUrl(blob);
    html.document.createElement('a')
      as html.AnchorElement
      ..href = url
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
  }
  return null;
}
