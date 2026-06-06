import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'download_helper.dart';

const _grokApiKey = String.fromEnvironment('XAI_API_KEY');
const _grokBaseUrl = String.fromEnvironment(
  'GROK_BASE_URL',
  defaultValue: 'https://api.x.ai/v1',
);
const _grokImageModel = String.fromEnvironment(
  'GROK_IMAGE_MODEL',
  defaultValue: 'grok-imagine-image',
);

enum ImageCategory {
  landscape('풍경', '🌄', Color(0xFF4CAF50)),
  woman('여자', '👩', Color(0xFFE91E8C)),
  man('남자', '👨', Color(0xFF2196F3));

  const ImageCategory(this.label, this.emoji, this.color);
  final String label;
  final String emoji;
  final Color color;
}

enum BodyType {
  slim('슬림', 'slim petite figure, slender and lean body'),
  normal('보통', 'average normal figure, regular build'),
  chubby('통통', 'slightly chubby curvy figure, soft fuller body, moderately overweight'),
  athletic('뚱뚱', 'overweight chubby body, large figure, big size body');

  const BodyType(this.label, this.description);
  final String label;
  final String description;
}

const _prompts = {
  ImageCategory.landscape: [
    'A breathtaking aurora borealis over snowy mountains, vibrant green and purple colors, cinematic',
    'A golden sunset over a calm ocean, soft reflections on the water, serene and beautiful',
    'Cherry blossoms in full bloom along a quiet path, soft pink petals falling gently',
    'A magical forest with glowing fireflies at dusk, enchanting and dreamy atmosphere',
    'A colorful underwater world with tropical fish and coral reefs, vivid and peaceful',
    'A vast lavender field under a pastel purple sunset sky, dreamy landscape',
    'A crystal clear mountain lake reflecting snow-capped peaks at golden hour',
    'A starry night sky over a quiet countryside, milky way clearly visible, peaceful',
    'A garden filled with colorful wildflowers in soft morning light, cheerful and bright',
    'A tiny village covered in snow at night, warm light from windows, cozy winter scene',
    'Rolling green hills under a dramatic cloudy sky with sunbeams breaking through',
    'A lone lighthouse on a rocky cliff at sunset, waves crashing below, dramatic scenery',
    'A hot air balloon floating over colorful autumn forests, joyful and whimsical',
    'A peaceful Japanese Zen garden with raked sand, cherry blossoms, and stone lanterns',
  ],
  ImageCategory.woman: [
    'Full body head to toe shot of a Korean woman with K-pop idol-like beauty, full figure from head to feet, wearing trendy oversized beige trench coat, slim jeans, white sneakers, Seoul street fashion, feet clearly visible',
    'Full body head to toe shot of a Korean woman with celebrity-like visuals, entire body from head to feet, wearing cozy knit sweater, wide leg trousers, loafers, minimal accessories, chic daily look, shoes visible',
    'Full body head to toe shot of a Korean woman with movie star-like appearance, complete figure from top to bottom, wearing chic white button-up shirt, high waist straight jeans, small shoulder bag, white sneakers, clean Korean style',
    'Full body head to toe shot of a Korean woman with idol-like charm and beauty, whole body visible including feet, wearing soft pastel hoodie, jogger pants, chunky sneakers, effortless Korean street look',
    'Full body head to toe shot of a Korean woman with actress-level visuals, full figure from hair to shoes, wearing elegant slip dress over long sleeve top, ankle boots, layered necklace, trendy Korean style',
    'Full body head to toe shot of a Korean woman with K-pop celebrity-like face, entire body visible, wearing cropped leather jacket, high waist flare jeans, pointed toe heels, chic Korean urban fashion, heels visible',
    'Full body head to toe shot of a Korean woman with supermodel-like beauty, complete look from head to feet, wearing casual linen wide pants, fitted tank top, open shirt layer, sandals, summer Korean daily look',
    'Full body head to toe shot of a Korean woman with drama actress-like visuals, full figure including shoes, wearing oversized cardigan, mini skirt, knee-high socks, loafers, adorable Korean campus look',
    'Full body head to toe shot of a Korean woman with top star-like appearance, whole body from head to toe, wearing tailored blazer, straight cut trousers, white tee, oxford shoes, smart casual Korean style',
    'Full body head to toe shot of a Korean woman with idol group member-like beauty, entire figure visible, wearing puffer vest, long sleeve tee, wide cargo pants, sneakers all visible, sporty Korean street fashion',
  ],
  ImageCategory.man: [
    'Full body head to toe shot of a Korean man with K-pop idol-like visuals, full figure from head to feet, wearing oversized graphic tee, straight leg jeans, clean white sneakers fully visible, casual Korean street fashion',
    'Full body head to toe shot of a Korean man with celebrity-like appearance, entire body from top to bottom, wearing beige trench coat, slim chino pants, white shirt, loafers visible, clean Korean daily look',
    'Full body head to toe shot of a Korean man with movie star-like looks, complete figure head to feet, wearing cozy knit polo sweater, straight fit trousers, leather sneakers clearly shown, smart casual Korean style',
    'Full body head to toe shot of a Korean man with idol-like charm and face, whole body including feet, wearing hoodie under open flannel shirt, slim jeans, chunky sneakers, relaxed Korean street style',
    'Full body head to toe shot of a Korean man with actor-level visuals, full figure from hair to shoes, wearing tailored suit jacket, white tee, straight jeans, dress shoes clearly visible, stylish Korean business casual',
    'Full body head to toe shot of a Korean man with K-pop celebrity-like appearance, entire body visible, wearing puffer jacket, turtleneck, slim pants, boots shown from top to bottom, Korean winter fashion',
    'Full body head to toe shot of a Korean man with drama actor-like visuals, complete look head to toe, wearing linen shirt, wide leg trousers, sandals visible, minimal accessories, relaxed Korean summer fashion',
    'Full body head to toe shot of a Korean man with top idol group member-like face, full figure including shoes, wearing varsity jacket, simple tee, straight jeans, classic sneakers, effortless Korean casual style',
    'Full body head to toe shot of a Korean man with supermodel-like looks, whole body from head to feet, wearing long cardigan, inner tee, jogger pants, slip-on shoes visible, cozy Korean layered look',
    'Full body head to toe shot of a Korean man with top star-like visuals, entire figure top to bottom, wearing denim jacket, striped shirt, chino shorts, canvas sneakers clearly shown, fresh Korean spring look',
  ],
};

class _HistoryItem {
  final Uint8List? bytes;
  final String? imageUrl;
  final String filename;
  _HistoryItem.fromBytes(Uint8List this.bytes, this.filename) : imageUrl = null;
  _HistoryItem.fromUrl(String this.imageUrl, this.filename) : bytes = null;

  Widget buildImage({BoxFit fit = BoxFit.contain}) {
    if (imageUrl != null) return Image.network(imageUrl!, fit: fit);
    return Image.memory(bytes!, fit: fit);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const JoaApp());
}

class JoaApp extends StatelessWidget {
  const JoaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '기분 좋아지는 이미지',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      debugShowCheckedModeBanner: false,
      home: const ImageRequestPage(),
    );
  }
}

class ImageRequestPage extends StatefulWidget {
  const ImageRequestPage({super.key});

  @override
  State<ImageRequestPage> createState() => _ImageRequestPageState();
}

class _ImageRequestPageState extends State<ImageRequestPage> {
  final _random = Random();
  bool _isLoading = false;
  String? _errorMessage;
  _HistoryItem? _currentImage;
  final List<_HistoryItem> _history = [];
  BodyType _selectedBodyType = BodyType.normal;
  bool _useWeather = false;
  String? _weatherInfo;
  Box? _historyBox;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final box = await Hive.openBox('joa_history');
    _historyBox = box;
    final keys = box.keys.cast<String>().toList()..sort();
    final loaded = <_HistoryItem>[];
    for (final key in keys.reversed) {
      final b64 = box.get(key) as String?;
      if (b64 == null) continue;
      try {
        loaded.add(_HistoryItem.fromBytes(base64Decode(b64), key));
      } catch (_) {}
    }
    if (mounted && loaded.isNotEmpty) {
      setState(() {
        _history.addAll(loaded);
        _currentImage = _history.first;
      });
    }
  }

  Future<void> _saveToBox(_HistoryItem item) async {
    if (item.bytes == null) return;
    await _historyBox?.put(item.filename, base64Encode(item.bytes!));
    // 최대 30개 유지
    final box = _historyBox;
    if (box != null && box.length > 30) {
      final oldest = (box.keys.cast<String>().toList()..sort()).first;
      await box.delete(oldest);
    }
  }

  Future<void> _deleteFromBox(String filename) async {
    await _historyBox?.delete(filename);
  }

  Future<String?> _fetchWeatherHint() async {
    try {
      final res = await http
          .get(Uri.parse('https://wttr.in/?format=j1'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cur = (json['current_condition'] as List)[0] as Map<String, dynamic>;
      final temp = cur['temp_C'];
      final desc = (cur['weatherDesc'] as List)[0]['value'] as String;
      setState(() => _weatherInfo = '오늘 $temp°C');
      return 'today weather in Korea: $temp°C, $desc';
    } catch (e) {
      debugPrint('[Weather] 날씨 조회 실패: $e');
      return null;
    }
  }

  String _buildWeatherLandscapePrompt(String weatherHint) {
    final lower = weatherHint.toLowerCase();
    if (lower.contains('rain') || lower.contains('drizzle') || lower.contains('shower')) {
      return 'A breathtaking rainy landscape in Korea, lush green hillside glistening with rain, misty mountains in background, dramatic atmospheric photography, cinematic quality';
    }
    if (lower.contains('snow') || lower.contains('blizzard') || lower.contains('sleet')) {
      return 'A breathtaking snowy mountain landscape in Korea, pristine white snow covering forests and peaks, serene winter beauty, stunning scenic photography, cinematic quality';
    }
    if (lower.contains('cloud') || lower.contains('overcast') || lower.contains('fog') || lower.contains('mist')) {
      return 'A dramatic cloudy landscape in Korea, moody sky with rays of light breaking through clouds over rolling hills, atmospheric and stunning nature photography';
    }
    if (lower.contains('sunny') || lower.contains('clear') || lower.contains('fine')) {
      return 'A breathtaking sunny landscape in Korea, crystal clear sky, golden sunlight over green mountains and valleys, vibrant and beautiful scenic photography';
    }
    return 'A breathtaking natural landscape in Korea reflecting the atmosphere of $weatherHint, stunning scenic photography, beautiful lighting, cinematic quality';
  }

  Future<void> _requestImage(ImageCategory category) async {
    if (!kIsWeb && _grokApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('XAI_API_KEY가 설정되지 않았습니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String prompt;

      if (category == ImageCategory.landscape) {
        if (_useWeather) {
          final weatherHint = await _fetchWeatherHint();
          if (weatherHint != null) {
            prompt = _buildWeatherLandscapePrompt(weatherHint);
          } else {
            final prompts = _prompts[category]!;
            prompt = prompts[_random.nextInt(prompts.length)];
          }
        } else {
          final prompts = _prompts[category]!;
          prompt = prompts[_random.nextInt(prompts.length)];
        }
      } else {
        final isWoman = category == ImageCategory.woman;
        final prompts = _prompts[category]!;
        prompt = prompts[_random.nextInt(prompts.length)];
        final gender = isWoman
            ? 'Korean woman with K-pop idol-like beauty'
            : 'Korean man with K-pop idol-like visuals';
        if (_useWeather) {
          final weatherHint = await _fetchWeatherHint();
          if (weatherHint != null) {
            prompt = 'Full body head to toe shot of a $gender, full figure from head to feet, '
                'wearing a fashionable outfit perfectly suited for the current weather ($weatherHint), '
                'stylish Korean street fashion, weather-appropriate clothes and shoes clearly visible, '
                '${_selectedBodyType.description}';
          } else {
            prompt = '$prompt, ${_selectedBodyType.description}';
          }
        } else {
          prompt = '$prompt, ${_selectedBodyType.description}';
        }
      }

      final uri = kIsWeb
          ? Uri.parse('/api/image')
          : Uri.parse('$_grokBaseUrl/images/generations');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (!kIsWeb) 'Authorization': 'Bearer $_grokApiKey',
        },
        body: jsonEncode({
          'model': _grokImageModel,
          'prompt': prompt,
          'n': 1,
          'aspect_ratio': '9:16',
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('API 오류(${response.statusCode}): ${response.body}');
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final data = responseJson['data'];
      if (data is! List || data.isEmpty || data.first is! Map<String, dynamic>) {
        throw Exception('이미지 데이터가 없습니다.');
      }

      final item = data.first as Map<String, dynamic>;
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final _HistoryItem historyItem;

      if (item['b64_json'] is String) {
        historyItem = _HistoryItem.fromBytes(base64Decode(item['b64_json'] as String), filename);
      } else if (item['url'] is String) {
        if (kIsWeb) {
          historyItem = _HistoryItem.fromUrl(item['url'] as String, filename);
        } else {
          final imgRes = await http.get(Uri.parse(item['url'] as String));
          historyItem = _HistoryItem.fromBytes(imgRes.bodyBytes, filename);
        }
      } else {
        throw Exception('지원되지 않는 응답 형식입니다.');
      }

      setState(() {
        _currentImage = historyItem;
        _history.insert(0, historyItem);
      });
      await _saveToBox(historyItem);
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadImage(_HistoryItem item) async {
    final error = await saveImageToDevice(item.bytes, item.imageUrl, item.filename);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error == null ? '저장했습니다.' : '저장 실패: $error')),
      );
    }
  }

  void _showThumbnailMenu(int index) {
    final item = _history[index];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('다운로드'),
              onTap: () {
                Navigator.pop(ctx);
                _downloadImage(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteFromBox(item.filename);
                setState(() {
                  if (_currentImage == item) _currentImage = null;
                  _history.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  ...ImageCategory.values.map((category) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _requestImage(category),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: category.color,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: category.color.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            '${category.emoji}\n${category.label}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          _useWeather = !_useWeather;
                          if (!_useWeather) _weatherInfo = null;
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _useWeather
                              ? const Color(0xFF00BCD4)
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          _useWeather && _weatherInfo != null
                              ? '🌤\n$_weatherInfo'
                              : '🌤\n날씨코디',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('체형', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  ...BodyType.values.map((type) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedBodyType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedBodyType == type ? Colors.indigo : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type.label,
                          style: TextStyle(
                            color: _selectedBodyType == type ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _currentImage == null
                    ? const Center(
                        child: Text(
                          '위 버튼을 누르면\n기분 좋아지는 이미지가 나타납니다 ✨',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Stack(
                        children: [
                          InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 5.0,
                            child: _currentImage!.buildImage(fit: BoxFit.contain),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: FloatingActionButton.small(
                              heroTag: 'download',
                              onPressed: () => _downloadImage(_currentImage!),
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.download),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final isSelected = item == _currentImage;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _currentImage = item),
                        onLongPress: () => _showThumbnailMenu(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: isSelected
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: item.buildImage(fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
