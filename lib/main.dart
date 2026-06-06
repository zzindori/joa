import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'download_helper.dart';

const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const _geminiModel = 'gemini-2.5-flash-image';

// ── 프리미엄 설정 ──
const _maxFreeImages = 5;
const _maxDailyImages = 10;
const _storeUrl = 'https://smartstore.naver.com/wowhit'; // 이용권 상품 페이지

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

  // ── 프리미엄 상태 ──
  Box? _settingsBox;
  int _freeUsed = 0;
  String? _subExpiry; // "YYYY-MM-DD", null이면 미구독
  int _dailyCount = 0;
  String _dailyDate = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSettings();
  }

  // ── 히스토리 ──

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
    final box = _historyBox;
    if (box != null && box.length > 30) {
      final oldest = (box.keys.cast<String>().toList()..sort()).first;
      await box.delete(oldest);
    }
  }

  Future<void> _deleteFromBox(String filename) async {
    await _historyBox?.delete(filename);
  }

  // ── 날씨 ──

  Future<({int tempC, String desc})?> _fetchWeather() async {
    try {
      final res = await http
          .get(Uri.parse('https://wttr.in/?format=j1'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cur = (json['current_condition'] as List)[0] as Map<String, dynamic>;
      final tempC = int.parse(cur['temp_C'].toString());
      final desc = (cur['weatherDesc'] as List)[0]['value'] as String;
      setState(() => _weatherInfo = '오늘 $tempC°C');
      return (tempC: tempC, desc: desc);
    } catch (e) {
      debugPrint('[Weather] 날씨 조회 실패: $e');
      return null;
    }
  }

  String _weatherOutfitHint(int tempC) {
    if (tempC <= 0)  return 'heavy winter padding coat, thick scarf, winter boots, very cold weather outfit';
    if (tempC <= 5)  return 'heavy winter coat, knit sweater, warm pants, boots, cold weather outfit';
    if (tempC <= 10) return 'thick jacket or wool coat, layered warm outfit, chilly weather';
    if (tempC <= 15) return 'light jacket or cardigan, long sleeve shirt, mild cool weather outfit';
    if (tempC <= 20) return 'light jacket or hoodie, casual long sleeve, comfortable mild weather outfit';
    if (tempC <= 25) return 'light t-shirt or thin blouse, no jacket needed, comfortable warm weather outfit';
    if (tempC <= 30) return 'short sleeve t-shirt, summer casual outfit, warm weather';
    return 'very light summer clothes, sleeveless or tank top, hot weather outfit';
  }

  String _buildWeatherLandscapePrompt(int tempC, String desc) {
    final lower = desc.toLowerCase();
    if (lower.contains('rain') || lower.contains('drizzle') || lower.contains('shower')) {
      return 'A breathtaking rainy landscape in Korea, lush green hillside glistening with rain, misty mountains in background, dramatic atmospheric photography, cinematic quality';
    }
    if (lower.contains('snow') || lower.contains('blizzard') || lower.contains('sleet') || tempC <= 0) {
      return 'A breathtaking snowy mountain landscape in Korea, pristine white snow covering forests and peaks, serene winter beauty, stunning scenic photography, cinematic quality';
    }
    if (lower.contains('cloud') || lower.contains('overcast') || lower.contains('fog') || lower.contains('mist')) {
      return 'A dramatic cloudy landscape in Korea, moody sky with rays of light breaking through clouds over rolling hills, atmospheric and stunning nature photography';
    }
    if (tempC >= 28) {
      return 'A vibrant hot summer landscape in Korea, bright sunlight over lush green fields, clear blue sky, vivid and energetic summer scenery, cinematic quality';
    }
    return 'A breathtaking sunny landscape in Korea, crystal clear sky, golden sunlight over green mountains and valleys, vibrant and beautiful scenic photography';
  }

  // ── 프리미엄: 유틸 / 상태 ──

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('joa_settings');
    _settingsBox = box;
    final today = _todayStr();
    final storedDate = box.get('dailyDate', defaultValue: '') as String;
    final storedCount = box.get('dailyCount', defaultValue: 0) as int;
    if (storedDate != today) {
      await box.put('dailyDate', today);
      await box.put('dailyCount', 0);
    }
    if (mounted) {
      setState(() {
        _freeUsed = box.get('freeUsed', defaultValue: 0) as int;
        _subExpiry = box.get('subExpiry') as String?;
        _dailyDate = today;
        _dailyCount = storedDate == today ? storedCount : 0;
      });
    }
  }

  bool _isSubscribed() {
    if (_subExpiry == null) return false;
    try {
      return DateTime.parse(_subExpiry!).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  Future<void> _incrementUsage() async {
    final box = _settingsBox;
    if (box == null) return;
    final today = _todayStr();
    if (_isSubscribed()) {
      final newCount = _dailyCount + 1;
      await box.put('dailyCount', newCount);
      await box.put('dailyDate', today);
      setState(() {
        _dailyCount = newCount;
        _dailyDate = today;
      });
    } else {
      final newFree = _freeUsed + 1;
      await box.put('freeUsed', newFree);
      setState(() => _freeUsed = newFree);
    }
  }

  // ── 프리미엄: 코드 등록 ──

  Future<String?> _redeemCode(String code) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
    if (normalized.isEmpty) return '코드를 입력해주세요';

    final used = (_settingsBox?.get('usedCodes') as List?)?.cast<String>() ?? [];
    if (used.contains(normalized)) return '이미 사용된 코드입니다';

    try {
      final uri = kIsWeb
          ? Uri.parse('/api/redeem')
          : Uri.parse('https://web-tau-nine-22.vercel.app/api/redeem');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'code': normalized}),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final expiresAt = data['expiresAt'] as String;
        used.add(normalized);
        await _settingsBox?.put('usedCodes', used);
        await _settingsBox?.put('subExpiry', expiresAt);
        setState(() => _subExpiry = expiresAt);
        return null; // 성공
      }
      return data['error'] as String? ?? '코드 오류';
    } catch (e) {
      return '네트워크 오류';
    }
  }

  // ── 프리미엄: 다이얼로그 ──

  void _showCodeInputDialog({VoidCallback? onActivated}) {
    final codeCtrl = TextEditingController();
    bool loading = false;
    String? error;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, dialogSetState) => AlertDialog(
          title: const Text('코드 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('구매 후 이메일로 받은 코드를 입력하세요.'),
              const SizedBox(height: 4),
              const Text('예) JOA-0001-ABCDEF',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  hintText: 'JOA-XXXX-XXXXXX',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => dialogSetState(() => error = null),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      dialogSetState(() {
                        loading = true;
                        error = null;
                      });
                      final err = await _redeemCode(codeCtrl.text);
                      if (!mounted) return;
                      dialogSetState(() {
                        loading = false;
                        error = err;
                      });
                      if (err == null) {
                        Navigator.pop(ctx);
                        onActivated?.call();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('구독 활성화 완료! $_subExpiry까지 이용 가능합니다 🎉'),
                            ),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaywallDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('무료 이용권 소진 😮'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('무료 이미지 5장을 모두 사용했습니다.'),
            SizedBox(height: 8),
            Text(
              '연간 이용권을 구매하면\n하루 10장씩 1년간 이용할 수 있습니다.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showCodeInputDialog();
            },
            child: const Text('코드 입력'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(_storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('구매하러 가기'),
          ),
        ],
      ),
    );
  }

  void _showDailyLimitDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오늘 한도 초과 😅'),
        content: Text(
          '오늘 이용 한도(${_maxDailyImages}장)에 도달했습니다.\n내일 다시 이용하실 수 있습니다.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) => AlertDialog(
          title: const Text('이용 현황'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSubscribed()) ...[
                Row(children: [
                  const Icon(Icons.verified, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('구독중 · $_subExpiry까지'),
                ]),
                const SizedBox(height: 4),
                Text('오늘 사용: $_dailyCount / $_maxDailyImages장'),
              ] else ...[
                Row(children: [
                  const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text('무료 $_freeUsed / $_maxFreeImages장 사용'),
                ]),
                const SizedBox(height: 4),
                const Text(
                  '연간 이용권 구매 후 코드를 입력하세요',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const Divider(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCodeInputDialog();
                },
                icon: const Icon(Icons.vpn_key, size: 18),
                label: const Text('코드 입력'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(_storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text('스마트스토어에서 구매'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 생성 버튼 핸들러 ──

  void _onCategoryTapped(ImageCategory category) {
    if (_isLoading) return;
    if (_isSubscribed()) {
      if (_dailyCount >= _maxDailyImages) {
        _showDailyLimitDialog();
        return;
      }
    } else {
      if (_freeUsed >= _maxFreeImages) {
        _showPaywallDialog();
        return;
      }
    }
    _requestImage(category);
  }

  // ── 이미지 생성 ──

  Future<void> _requestImage(ImageCategory category) async {
    if (!kIsWeb && _geminiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GEMINI_API_KEY가 설정되지 않았습니다.')),
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
          final weather = await _fetchWeather();
          prompt = weather != null
              ? _buildWeatherLandscapePrompt(weather.tempC, weather.desc)
              : _prompts[category]![_random.nextInt(_prompts[category]!.length)];
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
          final weather = await _fetchWeather();
          if (weather != null) {
            final outfit = _weatherOutfitHint(weather.tempC);
            prompt = 'Full body head to toe shot of a $gender, full figure from head to feet, '
                'wearing $outfit, stylish Korean street fashion, '
                'clothes and shoes clearly visible, ${_selectedBodyType.description}';
          } else {
            prompt = '$prompt, ${_selectedBodyType.description}';
          }
        } else {
          prompt = '$prompt, ${_selectedBodyType.description}';
        }
      }

      final http.Response response;
      if (kIsWeb) {
        response = await http.post(
          Uri.parse('/api/image'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'prompt': prompt}),
        );
      } else {
        response = await http.post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': '$prompt, vertical 9:16 portrait aspect ratio'}
                ]
              }
            ],
            'generationConfig': {
              'responseModalities': ['IMAGE']
            },
          }),
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('API 오류(${response.statusCode}): ${response.body}');
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final String b64;
      if (kIsWeb) {
        final data = responseJson['data'] as List;
        b64 = (data.first as Map<String, dynamic>)['b64_json'] as String;
      } else {
        final candidates = responseJson['candidates'] as List;
        final parts =
            (candidates.first as Map<String, dynamic>)['content']['parts']
                as List;
        final imagePart =
            parts.firstWhere((p) => (p as Map)['inlineData'] != null)
                as Map<String, dynamic>;
        b64 = imagePart['inlineData']['data'] as String;
      }

      final filename = '${DateTime.now().millisecondsSinceEpoch}.png';
      final historyItem = _HistoryItem.fromBytes(base64Decode(b64), filename);

      setState(() {
        _currentImage = historyItem;
        _history.insert(0, historyItem);
      });
      await _saveToBox(historyItem);
      await _incrementUsage(); // 사용량 증가
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
    final error =
        await saveImageToDevice(item.bytes, item.imageUrl, item.filename);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error == null ? '저장했습니다.' : '저장 실패: $error')),
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
              title:
                  const Text('삭제', style: TextStyle(color: Colors.red)),
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
    final subscribed = _isSubscribed();
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 46,
        title: const Text('JoA',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _showSettingsDialog,
            icon: Icon(
              subscribed ? Icons.verified_outlined : Icons.lock_outline,
              size: 16,
              color: subscribed ? Colors.green : Colors.orange,
            ),
            label: Text(
              subscribed
                  ? '오늘 $_dailyCount/$_maxDailyImages'
                  : '무료 $_freeUsed/$_maxFreeImages',
              style: TextStyle(
                fontSize: 12,
                color: subscribed ? Colors.green : Colors.orange,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: _showSettingsDialog,
            tooltip: '설정',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  ...ImageCategory.values.map((category) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ElevatedButton(
                          onPressed: () => _onCategoryTapped(category),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: category.color,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                category.color.withValues(alpha: 0.4),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            '${category.emoji}\n${category.label}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
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
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
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
                  const Text('체형',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  ...BodyType.values.map((type) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedBodyType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selectedBodyType == type
                                  ? Colors.indigo
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              type.label,
                              style: TextStyle(
                                color: _selectedBodyType == type
                                    ? Colors.white
                                    : Colors.black87,
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
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
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
                                    child: SizedBox.expand(
                                      child: _currentImage!
                                          .buildImage(fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: FloatingActionButton.small(
                                      heroTag: 'download',
                                      onPressed: () =>
                                          _downloadImage(_currentImage!),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
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
