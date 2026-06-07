import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

import 'download_helper.dart';

const _geminiModel = 'gemini-2.5-flash-image';
const _maxFreeImages = 5;
const _maxDailyImages = 30;
const _storeUrl = 'https://smartstore.naver.com/wowhit/products/13625209650';

// ── 카테고리 ──────────────────────────────────────────

enum ImageCategory {
  landscape('풍경', '🌄', Color(0xFF43A047)),
  woman('여자', '👩', Color(0xFFE91E8C)),
  man('남자', '👨', Color(0xFF1E88E5));

  const ImageCategory(this.label, this.emoji, this.color);
  final String label;
  final String emoji;
  final Color color;
}

// ── 옵션 열거형 ───────────────────────────────────────

enum AgeGroup {
  twenties('20대'),
  thirties('30대'),
  forties('40대'),
  fifties('50대+');

  const AgeGroup(this.label);
  final String label;

  String prompt(ImageCategory cat) {
    final isWoman = cat == ImageCategory.woman;
    return switch (this) {
      twenties => isWoman
          ? 'in her 20s, youthful beautiful face, fresh attractive appearance'
          : 'in his 20s, handsome youthful face, fresh attractive appearance',
      thirties => isWoman
          ? 'in her 30s, elegant mature beautiful face, sophisticated appearance'
          : 'in his 30s, mature handsome face, refined distinguished appearance',
      forties => isWoman
          ? 'in her 40s, graceful charming face, dignified elegant appearance'
          : 'in his 40s, distinguished mature face, confident dignified appearance',
      fifties => isWoman
          ? 'in her 50s, distinguished elegant face, graceful dignified appearance'
          : 'in his 50s, distinguished dignified face, authoritative mature appearance',
    };
  }
}

enum BodyType {
  slim('슬림', 'slim petite figure, slender and lean body'),
  normal('보통', 'average normal figure, regular build'),
  chubby('통통', 'slightly chubby curvy figure, soft fuller body'),
  big('뚱뚱', 'overweight chubby body, large figure, big size body');

  const BodyType(this.label, this.description);
  final String label;
  final String description;
}

enum StyleType {
  casual('캐주얼', 'casual everyday Korean street style outfit'),
  office('오피스룩', 'smart Korean business casual office wear'),
  street('스트릿', 'trendy urban Korean street fashion'),
  formal('포멀', 'formal elegant sophisticated Korean attire');

  const StyleType(this.label, this.description);
  final String label;
  final String description;
}

enum Season {
  current('현재날씨', '🌤'),
  spring('봄/가을', '🌸'),
  summer('여름', '☀️'),
  winter('겨울', '❄️');

  const Season(this.label, this.emoji);
  final String label;
  final String emoji;

  String get outfitHint => switch (this) {
        spring =>
          'light jacket or cardigan layered outfit for spring or autumn, comfortable mild weather style',
        summer => 'light summer outfit, breathable casual clothing, warm weather style',
        winter =>
          'warm winter coat with scarf and boots, cold weather outfit, layered winter style',
        _ => 'comfortable casual outfit',
      };

  String get landscapePrompt => switch (this) {
        spring =>
          'Beautiful spring cherry blossom landscape in Korea, soft pink petals falling gently, warm sunlight, dreamy and romantic atmosphere, cinematic quality photography',
        summer =>
          'Vibrant summer landscape in Korea, lush green mountains and forests, bright sunshine, clear blue sky, vivid energetic scenery, cinematic quality',
        winter =>
          'Serene snowy winter landscape in Korea, pristine white snow covering forests and mountains, peaceful quiet atmosphere, stunning scenic photography',
        _ =>
          'Beautiful scenic landscape in Korea, golden sunlight over green mountains, clear sky, cinematic quality photography',
      };
}

enum Vibe {
  pure('청순'),
  chic('시크'),
  lively('발랄'),
  luxury('고급스러운');

  const Vibe(this.label);
  final String label;

  String prompt(ImageCategory cat) {
    final isWoman = cat == ImageCategory.woman;
    return switch (this) {
      pure => isWoman
          ? 'sweet innocent feminine pure style'
          : 'clean neat boyish fresh innocent style',
      chic => isWoman
          ? 'chic sophisticated stylish cool vibe'
          : 'sophisticated cool stylish edgy vibe',
      lively => isWoman
          ? 'lively bright cheerful energetic feminine style'
          : 'energetic fresh playful youthful masculine style',
      luxury => 'luxurious high-end premium fashion style',
    };
  }
}

// ── 히스토리 아이템 ────────────────────────────────────

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

// ── 앱 진입점 ─────────────────────────────────────────

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
      title: 'JoA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const ImageRequestPage(),
    );
  }
}

// ── 메인 페이지 ───────────────────────────────────────

class ImageRequestPage extends StatefulWidget {
  const ImageRequestPage({super.key});

  @override
  State<ImageRequestPage> createState() => _ImageRequestPageState();
}

class _ImageRequestPageState extends State<ImageRequestPage> {
  // 기본 상태
  bool _isLoading = false;
  String? _errorMessage;
  _HistoryItem? _currentImage;
  final List<_HistoryItem> _history = [];
  Box? _historyBox;

  // 옵션 상태
  ImageCategory _lastCategory = ImageCategory.woman;
  AgeGroup _ageGroup = AgeGroup.twenties;
  BodyType _bodyType = BodyType.normal;
  StyleType _styleType = StyleType.casual;
  Season _season = Season.current;
  Vibe _vibe = Vibe.chic;
  int? _currentTempC;

  // 프리미엄 상태
  Box? _settingsBox;
  int _freeUsed = 0;
  String? _subExpiry;
  String? _subCode;
  int _dailyCount = 0;
  String _dailyDate = '';
  String? _userApiKey;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSettings();
  }

  // ── 히스토리 ────────────────────────────────────────

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

  // ── 날씨 ────────────────────────────────────────────

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
      setState(() => _currentTempC = tempC);
      return (tempC: tempC, desc: desc);
    } catch (_) {
      return null;
    }
  }

  String _weatherOutfitHint(int tempC) {
    if (tempC <= 0) return 'heavy winter padding coat, thick scarf, winter boots, very cold weather outfit';
    if (tempC <= 5) return 'heavy winter coat, knit sweater, warm pants, boots, cold weather outfit';
    if (tempC <= 10) return 'thick jacket or wool coat, layered warm outfit, chilly weather';
    if (tempC <= 15) return 'light jacket or cardigan, long sleeve shirt, mild cool weather outfit';
    if (tempC <= 20) return 'light jacket or hoodie, casual long sleeve, comfortable mild weather outfit';
    if (tempC <= 25) return 'light t-shirt or thin blouse, no jacket needed, comfortable warm weather outfit';
    if (tempC <= 30) return 'short sleeve t-shirt, summer casual outfit, warm weather';
    return 'very light summer clothes, sleeveless or tank top, hot weather outfit';
  }

  String _weatherLandscapePrompt(int tempC, String desc) {
    final lower = desc.toLowerCase();
    if (lower.contains('rain') || lower.contains('drizzle') || lower.contains('shower')) {
      return 'Breathtaking rainy landscape in Korea, lush green hillside glistening with rain, misty mountains, dramatic atmospheric photography, cinematic quality';
    }
    if (lower.contains('snow') || lower.contains('blizzard') || tempC <= 0) {
      return 'Breathtaking snowy mountain landscape in Korea, pristine white snow covering forests and peaks, serene winter beauty, cinematic quality';
    }
    if (lower.contains('cloud') || lower.contains('overcast') || lower.contains('fog')) {
      return 'Dramatic cloudy landscape in Korea, moody sky with sunrays breaking through clouds over rolling hills, atmospheric nature photography';
    }
    if (tempC >= 28) {
      return 'Vibrant hot summer landscape in Korea, bright sunlight over lush green fields, clear blue sky, vivid energetic summer scenery, cinematic quality';
    }
    return 'Breathtaking sunny landscape in Korea, golden sunlight over green mountains and valleys, clear sky, cinematic quality';
  }

  // ── 프롬프트 빌더 ─────────────────────────────────────

  Future<String> _buildPrompt(ImageCategory category) async {
    if (category == ImageCategory.landscape) {
      if (_season == Season.current) {
        final weather = await _fetchWeather();
        return weather != null
            ? _weatherLandscapePrompt(weather.tempC, weather.desc)
            : Season.spring.landscapePrompt;
      }
      return _season.landscapePrompt;
    }

    final gender = category == ImageCategory.woman ? 'Korean woman' : 'Korean man';
    String seasonOutfit;

    if (_season == Season.current) {
      final weather = await _fetchWeather();
      seasonOutfit = weather != null
          ? _weatherOutfitHint(weather.tempC)
          : 'comfortable casual outfit';
    } else {
      seasonOutfit = _season.outfitHint;
    }

    return 'Full body head to toe portrait of a $gender, '
        '${_ageGroup.prompt(category)}, '
        'K-pop celebrity-level visual, top idol stunning face, '
        '${_bodyType.description}, '
        'wearing ${_styleType.description}, $seasonOutfit, '
        '${_vibe.prompt(category)}, '
        'complete outfit visible from head to shoes, shoes clearly visible, '
        'high quality Korean fashion editorial photography';
  }

  // ── 프리미엄 ─────────────────────────────────────────

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
        _subCode = box.get('subCode') as String?;
        _dailyDate = today;
        _dailyCount = storedDate == today ? storedCount : 0;
        _userApiKey = box.get('userApiKey') as String?;
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
      final n = _dailyCount + 1;
      await box.put('dailyCount', n);
      await box.put('dailyDate', today);
      setState(() { _dailyCount = n; _dailyDate = today; });
    } else {
      final n = _freeUsed + 1;
      await box.put('freeUsed', n);
      setState(() => _freeUsed = n);
    }
  }

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
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'code': normalized}))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final expiresAt = data['expiresAt'] as String;
        used.add(normalized);
        await _settingsBox?.put('usedCodes', used);
        await _settingsBox?.put('subExpiry', expiresAt);
        await _settingsBox?.put('subCode', normalized);
        setState(() { _subExpiry = expiresAt; _subCode = normalized; });
        return null;
      }
      return data['error'] as String? ?? '코드 오류';
    } catch (_) {
      return '네트워크 오류';
    }
  }

  // ── 다이얼로그 ───────────────────────────────────────

  void _showCodeInputDialog({VoidCallback? onActivated}) {
    final ctrl = TextEditingController();
    bool loading = false;
    String? error;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ds) => AlertDialog(
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
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: 'JOA-XXXX-XXXXXX',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => ds(() => error = null),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      ds(() { loading = true; error = null; });
                      final err = await _redeemCode(ctrl.text);
                      if (!mounted) return;
                      ds(() { loading = false; error = err; });
                      if (err == null) {
                        Navigator.pop(ctx);
                        onActivated?.call();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('구독 활성화! $_subExpiry까지 이용 가능합니다 🎉')),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        title: const Text('무료 이용권 소진'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('무료 이미지 5장을 모두 사용했습니다.'),
            SizedBox(height: 8),
            Text('월 이용권을 구매하면 하루 30장씩\n한 달간 이용할 수 있습니다.',
                style: TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _showCodeInputDialog(); },
            child: const Text('코드 입력'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(_storeUrl);
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        title: const Text('오늘 한도 초과'),
        content: Text('오늘 이용 한도(${_maxDailyImages}장)에 도달했습니다.\n내일 다시 이용하실 수 있습니다.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
        ],
      ),
    );
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SettingsPage(
          settingsBox: _settingsBox,
          isSubscribed: _isSubscribed(),
          subExpiry: _subExpiry,
          freeUsed: _freeUsed,
          dailyCount: _dailyCount,
          userApiKey: _userApiKey,
          onRedeemCode: _redeemCode,
          onStoreOpen: () async {
            final uri = Uri.parse(_storeUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
    _loadSettings();
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
                const Text('월 이용권 구매 후 코드를 입력하세요',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const Divider(height: 24),
              FilledButton.icon(
                onPressed: () { Navigator.pop(ctx); _showCodeInputDialog(); },
                icon: const Icon(Icons.vpn_key, size: 18),
                label: const Text('코드 입력'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(_storeUrl);
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text('스마트스토어에서 구매'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          ],
        ),
      ),
    );
  }

  // ── 이미지 생성 ──────────────────────────────────────

  void _onCategoryTapped(ImageCategory category) {
    if (_isLoading) return;
    setState(() => _lastCategory = category);
  }

  void _onGenerateTapped() {
    if (_isLoading) return;
    _checkAndGenerate(_lastCategory);
  }

  void _checkAndGenerate(ImageCategory category) {
    // 사용자 API 키가 있으면 한도 무시
    if (_userApiKey != null && _userApiKey!.isNotEmpty) {
      _generateImage(category);
      return;
    }
    if (_isSubscribed()) {
      if (_dailyCount >= _maxDailyImages) { _showDailyLimitDialog(); return; }
    } else {
      if (_freeUsed >= _maxFreeImages) { _showPaywallDialog(); return; }
    }
    _generateImage(category);
  }

  Future<void> _generateImage(ImageCategory category) async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final prompt = await _buildPrompt(category);

      final uri = kIsWeb
          ? Uri.parse('/api/image')
          : Uri.parse('https://web-tau-nine-22.vercel.app/api/image');

      final body = <String, dynamic>{'prompt': prompt};
      final userKey = _userApiKey;
      if (userKey != null && userKey.isNotEmpty) {
        body['apiKey'] = userKey;
      } else if (_subCode != null && _subCode!.isNotEmpty) {
        body['subCode'] = _subCode;
      }

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('API 오류(${response.statusCode}): ${response.body}');
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final data = responseJson['data'] as List;
      final b64 = (data.first as Map<String, dynamic>)['b64_json'] as String;

      final filename = '${DateTime.now().millisecondsSinceEpoch}.png';
      final item = _HistoryItem.fromBytes(base64Decode(b64), filename);
      setState(() {
        _currentImage = item;
        _history.insert(0, item);
      });
      await _saveToBox(item);
      if (userKey == null || userKey.isEmpty) await _incrementUsage();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              leading: const Icon(Icons.download_rounded),
              title: const Text('다운로드'),
              onTap: () { Navigator.pop(ctx); _downloadImage(item); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
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

  // ── UI 컴포넌트 ──────────────────────────────────────

  Widget _buildDropdown<T>(
    List<T> values,
    T current,
    void Function(T) onSelect,
    String Function(T) labelOf,
  ) {
    return PopupMenuButton<T>(
      onSelected: (v) => setState(() => onSelect(v)),
      itemBuilder: (ctx) => values
          .map((v) => PopupMenuItem<T>(
                value: v,
                child: Row(children: [
                  SizedBox(
                    width: 20,
                    child: v == current
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.indigo)
                        : null,
                  ),
                  Text(labelOf(v), style: const TextStyle(fontSize: 14)),
                ]),
              ))
          .toList(),
      child: _dropdownPill(labelOf(current)),
    );
  }

  Widget _buildSeasonDropdown() {
    return PopupMenuButton<Season>(
      onSelected: (v) => setState(() => _season = v),
      itemBuilder: (ctx) => Season.values
          .map((s) => PopupMenuItem<Season>(
                value: s,
                child: Row(children: [
                  SizedBox(
                    width: 20,
                    child: s == _season
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.indigo)
                        : null,
                  ),
                  Text('${s.emoji} ${s.label}', style: const TextStyle(fontSize: 14)),
                ]),
              ))
          .toList(),
      child: _dropdownPill(
        _season == Season.current && _currentTempC != null
            ? '${_season.emoji} $_currentTempC°C'
            : '${_season.emoji} ${_season.label}',
      ),
    );
  }

  Widget _dropdownPill(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey.shade500),
        ],
      ),
    );
  }

  // ── 빌드 ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final subscribed = _isSubscribed();
    final isPerson = _lastCategory != ImageCategory.landscape;
    final seasonLabel = _season == Season.current && _currentTempC != null
        ? '${_season.emoji} $_currentTempC°C'
        : '${_season.emoji} ${_season.label}';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3),
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 46,
        backgroundColor: const Color(0xFFF0F0F3),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('JoA',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1)),
        actions: [
          GestureDetector(
            onTap: _openSettings,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (_userApiKey?.isNotEmpty == true)
                    ? Colors.blue.shade50
                    : subscribed ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: (_userApiKey?.isNotEmpty == true)
                        ? Colors.blue.shade200
                        : subscribed ? Colors.green.shade200 : Colors.orange.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  (_userApiKey?.isNotEmpty == true)
                      ? Icons.key_rounded
                      : subscribed ? Icons.verified_outlined : Icons.lock_outline,
                  size: 13,
                  color: (_userApiKey?.isNotEmpty == true)
                      ? Colors.blue.shade700
                      : subscribed ? Colors.green.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  (_userApiKey?.isNotEmpty == true)
                      ? '내 키'
                      : subscribed ? '$_dailyCount/$_maxDailyImages' : '$_freeUsed/$_maxFreeImages',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: (_userApiKey?.isNotEmpty == true)
                          ? Colors.blue.shade700
                          : subscribed ? Colors.green.shade700 : Colors.orange.shade700),
                ),
              ]),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: _openSettings,
            color: Colors.grey.shade600,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [

            // ── 카드 1: 카테고리 선택 + 계절 ──
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(children: [
                // 카테고리 그룹
                ...ImageCategory.values.map((cat) {
                  final isSelected = _lastCategory == cat;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onCategoryTapped(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? cat.color : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text('${cat.emoji} ${cat.label}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                color: isSelected ? Colors.white : Colors.white54)),
                      ),
                    ),
                  );
                }),
                // 구분선
                Container(
                  width: 1, height: 26,
                  color: Colors.white.withValues(alpha: 0.12),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                // 계절 드롭다운 (별도 그룹)
                PopupMenuButton<Season>(
                  onSelected: (v) => setState(() => _season = v),
                  itemBuilder: (ctx) => Season.values
                      .map((s) => PopupMenuItem<Season>(
                            value: s,
                            child: Row(children: [
                              SizedBox(
                                  width: 20,
                                  child: s == _season
                                      ? const Icon(Icons.check_rounded,
                                          size: 15, color: Colors.indigo)
                                      : null),
                              Text('${s.emoji} ${s.label}'),
                            ]),
                          ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(seasonLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: Colors.white38),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── 카드 2: 옵션 + 계절 + 생성 버튼 (항상 표시) ──
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      if (isPerson) ...[
                        _buildDropdown(AgeGroup.values, _ageGroup,
                            (v) => _ageGroup = v, (v) => v.label),
                        _buildDropdown(BodyType.values, _bodyType,
                            (v) => _bodyType = v, (v) => v.label),
                        _buildDropdown(StyleType.values, _styleType,
                            (v) => _styleType = v, (v) => v.label),
                        _buildDropdown(Vibe.values, _vibe,
                            (v) => _vibe = v, (v) => v.label),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(width: 2),
                // 생성 버튼
                GestureDetector(
                  onTap: _onGenerateTapped,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? Colors.grey.shade300
                          : _lastCategory.color,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.grey.shade500))
                        : const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 8),

            // ── 메인 이미지 ──
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(_errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey.shade600)),
                            ),
                          )
                        : _currentImage == null
                            ? Center(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.auto_awesome_rounded,
                                      size: 52, color: Colors.grey.shade300),
                                  const SizedBox(height: 10),
                                  Text('✨ 버튼을 눌러 생성하세요',
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.grey.shade400)),
                                ]),
                              )
                            : Stack(children: [
                                InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 5.0,
                                  child: SizedBox.expand(
                                    child: _currentImage!.buildImage(fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: FloatingActionButton.small(
                                    heroTag: 'download',
                                    onPressed: () => _downloadImage(_currentImage!),
                                    backgroundColor: Colors.black45,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    child: const Icon(Icons.download_rounded, size: 20),
                                  ),
                                ),
                              ]),
              ),
            ),

            // ── 썸네일 ──
            if (_history.isNotEmpty)
              SizedBox(
                height: 74,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final isSelected = item == _currentImage;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _currentImage = item),
                        onLongPress: () => _showThumbnailMenu(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: isSelected
                                ? BoxDecoration(
                                    border: Border.all(color: Colors.indigo, width: 2),
                                    borderRadius: BorderRadius.circular(8))
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

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 설정 페이지 ───────────────────────────────────────

class SettingsPage extends StatefulWidget {
  final Box? settingsBox;
  final bool isSubscribed;
  final String? subExpiry;
  final int freeUsed;
  final int dailyCount;
  final String? userApiKey;
  final Future<String?> Function(String) onRedeemCode;
  final Future<void> Function() onStoreOpen;

  const SettingsPage({
    super.key,
    required this.settingsBox,
    required this.isSubscribed,
    required this.subExpiry,
    required this.freeUsed,
    required this.dailyCount,
    required this.userApiKey,
    required this.onRedeemCode,
    required this.onStoreOpen,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _keyCtrl;
  bool _obscure = true;
  bool _keySaved = false;
  String? _savedKey;
  bool _isSubscribed = false;
  String? _subExpiry;
  int _freeUsed = 0;
  int _dailyCount = 0;

  // 코드 입력 상태
  final _codeCtrl = TextEditingController();
  bool _codeLoading = false;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _savedKey = widget.userApiKey;
    _keyCtrl = TextEditingController(text: _savedKey ?? '');
    _isSubscribed = widget.isSubscribed;
    _subExpiry = widget.subExpiry;
    _freeUsed = widget.freeUsed;
    _dailyCount = widget.dailyCount;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _keyCtrl.text.trim();
    await widget.settingsBox?.put('userApiKey', key.isEmpty ? null : key);
    if (!mounted) return;
    setState(() {
      _savedKey = key.isEmpty ? null : key;
      _keySaved = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _keySaved = false);
  }

  Future<void> _redeemCode() async {
    setState(() { _codeLoading = true; _codeError = null; });
    final err = await widget.onRedeemCode(_codeCtrl.text);
    if (!mounted) return;
    if (err == null) {
      _codeCtrl.clear();
      final expiry = widget.settingsBox?.get('subExpiry') as String?;
      setState(() {
        _isSubscribed = true;
        _subExpiry = expiry;
        _codeLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구독 활성화! $_subExpiry까지 이용 가능합니다 🎉')),
      );
    } else {
      setState(() { _codeLoading = false; _codeError = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _savedKey != null && _savedKey!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F0F3),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('설정',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 내 API 키 ──
          _sectionCard(
            icon: Icons.key_rounded,
            iconColor: Colors.blue,
            title: '내 Gemini API 키',
            subtitle: '직접 발급한 키를 입력하면 무제한 사용\n(사용료는 본인 Google 계정 과금)',
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextField(
                    controller: _keyCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'AIzaSy...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // QR 스캔 버튼
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const QrScanPage()),
                    );
                    if (result != null && result.isNotEmpty) {
                      setState(() => _keyCtrl.text = result);
                      await _saveKey();
                    }
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.blue.shade600, size: 22),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (hasKey)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _keyCtrl.clear();
                        _saveKey();
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('삭제'),
                    ),
                  ),
                if (hasKey) const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: FilledButton(
                      onPressed: _keySaved ? null : _saveKey,
                      style: FilledButton.styleFrom(
                          backgroundColor: _keySaved ? Colors.green : Colors.blue,
                          disabledBackgroundColor: Colors.green,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (_keySaved) ...[
                          const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          const Text('저장됨'),
                        ] else
                          const Text('저장'),
                      ]),
                    ),
                  ),
                ),
              ]),
              if (hasKey)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text('내 키 사용 중 · 한도 없음',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 이용권 ──
          _sectionCard(
            icon: _isSubscribed ? Icons.verified_rounded : Icons.lock_outline_rounded,
            iconColor: _isSubscribed ? Colors.green : Colors.orange,
            title: '이용권',
            subtitle: _isSubscribed
                ? '구독 중 · $_subExpiry까지'
                : '무료 $_freeUsed/$_maxFreeImages장 사용',
            children: [
              TextField(
                controller: _codeCtrl,
                enabled: !_isSubscribed,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 13, letterSpacing: 1),
                decoration: InputDecoration(
                  hintText: _isSubscribed ? '구독 중입니다' : 'JOA-XXXX-XXXXXX',
                  hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  errorText: _codeError,
                ),
                onChanged: (_) => setState(() => _codeError = null),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: (_codeLoading || _isSubscribed) ? null : _redeemCode,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: _isSubscribed ? Colors.green : null,
                    disabledBackgroundColor: _isSubscribed ? Colors.green : null,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _codeLoading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : _isSubscribed
                        ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('구독 중'),
                          ])
                        : const Text('코드 등록'),
              ),
              const SizedBox(height: 8),
              if (!_isSubscribed)
                OutlinedButton.icon(
                  onPressed: widget.onStoreOpen,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: const Text('스마트스토어에서 구매'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 사용 통계 ──
          _sectionCard(
            icon: Icons.bar_chart_rounded,
            iconColor: Colors.indigo,
            title: '사용 통계',
            children: [
              _statRow('무료 사용', '$_freeUsed / $_maxFreeImages 장'),
              if (_isSubscribed)
                _statRow('오늘 사용', '$_dailyCount / $_maxDailyImages 장'),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── QR 스캐너 페이지 ──────────────────────────────────

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QR 코드 스캔',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (capture) {
            if (_scanned) return;
            final value = capture.barcodes.first.rawValue;
            if (value != null && value.isNotEmpty) {
              _scanned = true;
              Navigator.pop(context, value);
            }
          },
        ),
        Center(
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade400, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 48,
          left: 0, right: 0,
          child: Text(
            'wowhit 홈페이지에서 생성한\nAPI 키 QR 코드를 스캔하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
        ),
      ]),
    );
  }
}
