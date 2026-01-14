import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PlantCareApp());
}

class PlantCareApp extends StatelessWidget {
  const PlantCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        // ✅ GREEN THEME
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)), 
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- 🚀 CONFIGURATION ---
  final List<String> _apiKeys = [
    "AIzaSyBgxdbHuxzEg_UdLfY2ZyjFuCkiJblq9HQ",
    "AIzaSyBxqE5zmE2o_0Wkfc4knkX4D8LfpVRNDsQ", 
    "AIzaSyDgblmL_XWP1xzQfErcOAU10AnW6oTihWI",
  ];
  
  int _currentKeyIndex = 0; 

  // --- STATE ---
  String _selectedLang = 'en'; 
  File? _selectedImage; 
  File? _chatImage;     
  bool _isLoading = false;
  Map<String, dynamic>? _aiResult;
  String _temp = "--";
  String _wind = "--";
  String _weatherDesc = "Loading...";
  String _locationName = "Anekal, India"; 
  List<String> _historyLog = []; 

  // --- DICTIONARY ---
  final Map<String, Map<String, String>> _dict = {
    'en': {'app_name': 'PlantCare', 'scan': 'Scan Plant', 'scan_sub': 'Detect Disease', 'soil': 'Soil Test', 'soil_sub': 'Check Health', 'market': 'Market Prices', 'market_sub': 'Live Rates', 'alerts': 'Ask AI', 'alerts_sub': 'Chat Assistant', 'weather': 'Weather', 'loc': 'Your Location', 'buy': 'Buy Medicine', 'ask_hint': 'Ask a question...', 'history': 'Scan History', 'settings': 'Settings', 'about': 'About', 'cam': 'Camera', 'gal': 'Gallery', 'cancel': 'Cancel', 'retry': 'Retrying...'},
    'hi': {'app_name': 'प्लांट केयर', 'scan': 'पौधा स्कैन करें', 'scan_sub': 'रोग पहचानें', 'soil': 'मिट्टी परीक्षण', 'soil_sub': 'सेहत जांचें', 'market': 'बाज़ार भाव', 'market_sub': 'ताज़ा रेट', 'alerts': 'AI से पूछें', 'alerts_sub': 'सहायक', 'weather': 'मौसम', 'loc': 'आपका स्थान', 'buy': 'दवा खरीदें', 'ask_hint': 'प्रश्न पूछें...', 'history': 'स्कैन इतिहास', 'settings': 'सेटिंग्स', 'about': 'ऐप के बारे में', 'cam': 'कैमरा', 'gal': 'गैलरी', 'cancel': 'रद्द करें', 'retry': 'पुनः प्रयास...'},
    'ta': {'app_name': 'பிளாண்ட் கேர்', 'scan': 'பயிர் ஸ்கேன்', 'scan_sub': 'நோய் கண்டறிதல்', 'soil': 'மண் ஆய்வு', 'soil_sub': 'வளம் அறிதல்', 'market': 'சந்தை விலை', 'market_sub': 'விலை நிலவரம்', 'alerts': 'AI உதவி', 'alerts_sub': 'கேள்வி', 'weather': 'வானிலை', 'loc': 'இடம்', 'buy': 'மருந்து வாங்க', 'ask_hint': 'கேள்வி கேளுங்கள்...', 'history': 'வரலாறு', 'settings': 'அமைப்புகள்', 'about': 'பற்றி', 'cam': 'கேமரா', 'gal': 'கேலரி', 'cancel': 'ரத்து', 'retry': 'மீண்டும் முயற்சிக்கிறது...'},
    'kn': {'app_name': 'ಪ್ಲಾಂಟ್ ಕೇರ್', 'scan': 'ಸಸ್ಯ ಸ್ಕ್ಯಾನ್', 'scan_sub': 'ರೋಗ ಪತ್ತೆ', 'soil': 'ಮಣ್ಣು ಪರೀಕ್ಷೆ', 'soil_sub': 'ಆರೋಗ್ಯ', 'market': 'ಮಾರುಕಟ್ಟೆ ಬೆಲೆ', 'market_sub': 'ದರಗಳು', 'alerts': 'AI ಸಹಾಯ', 'alerts_sub': 'ಪ್ರಶ್ನೆ ಕೇಳಿ', 'weather': 'ಹವಾಮಾನ', 'loc': 'ಸ್ಥಳ', 'buy': 'ಔಷಧಿ', 'ask_hint': 'ಪ್ರಶ್ನೆ ಕೇಳಿ...', 'history': 'ಇತಿಹಾಸ', 'settings': 'ಸೆಟ್ಟಿಂಗ್', 'about': 'ಕುರಿತು', 'cam': 'ಕ್ಯಾಮೆರಾ', 'gal': 'ಗ್ಯಾಲರಿ', 'cancel': 'ರದ್ದು', 'retry': 'ಮರುಪ್ರಯತ್ನಿಸಲಾಗುತ್ತಿದೆ...'},
  };

  String t(String key) {
    if (_dict.containsKey(_selectedLang)) {
      return _dict[_selectedLang]![key] ?? key;
    }
    return _dict['en']![key] ?? key; 
  }

  String _getLangName(String code) {
    switch(code) {
      case 'hi': return "Hindi";
      case 'ta': return "Tamil";
      case 'kn': return "Kannada";
      default: return "English";
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchWeather(20.5937, 78.9629); 
    _loadHistory(); 
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _historyLog = prefs.getStringList('scan_history_v3') ?? [];
    });
  }

  Future<void> _saveToHistory(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();
    result['saved_date'] = DateTime.now().toString().split('.')[0];
    String entry = jsonEncode(result);
    setState(() {
      _historyLog.insert(0, entry);
    });
    await prefs.setStringList('scan_history_v3', _historyLog);
  }

  Future<void> _fetchWeather(double lat, double lng) async {
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current_weather=true');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _temp = "${data['current_weather']['temperature']}°C";
          _wind = "${data['current_weather']['windspeed']} km/h";
          _weatherDesc = "Live"; 
        });
      }
    } catch (e) { /* Ignore */ }
  }

  // --- FEATURES ---

  Future<void> _pickSourceAndScan(String mode) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 150,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Select Source", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); _processImage(ImageSource.camera, mode); },
                  icon: const Icon(Icons.camera_alt),
                  label: Text(t('cam')),
                ),
                ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); _processImage(ImageSource.gallery, mode); },
                  icon: const Icon(Icons.photo_library),
                  label: Text(t('gal')),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(ImageSource source, String mode) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
        _runGemini(mode, null);
      }
    } catch (e) { /* Prevent crash */ }
  }

  void _openChatDialog() {
    TextEditingController questionController = TextEditingController();
    _chatImage = null; 

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(t('alerts')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionController,
                      decoration: InputDecoration(hintText: t('ask_hint')),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    if (_chatImage != null) 
                      Stack(
                        children: [
                          Image.file(_chatImage!, height: 100, width: 100, fit: BoxFit.cover),
                          Positioned(
                            right: 0, top: 0,
                            child: InkWell(
                              onTap: () => setDialogState(() => _chatImage = null),
                              child: const Icon(Icons.close, color: Colors.red),
                            ),
                          )
                        ],
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate, color: Colors.blue),
                          onPressed: () async {
                            try {
                              final picker = ImagePicker();
                              final XFile? img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
                              if (img != null) setDialogState(() => _chatImage = File(img.path));
                            } catch (e) { }
                          },
                        ),
                        const Text("Add Photo", style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (questionController.text.isNotEmpty || _chatImage != null) {
                      _runGemini("CHAT", questionController.text);
                    }
                  },
                  child: const Text("Ask"),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- 🚀 GEMINI 2.5 FLASH ENGINE ---
  Future<void> _runGemini(String type, String? userText, {bool isRetry = false}) async {
    if (_apiKeys[0].contains("YOUR_API")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ KEY MISSING! Paste Google keys in main.dart"), backgroundColor: Colors.red));
      return;
    }

    if (!isRetry) setState(() => _isLoading = true);
    
    String currentKey = _apiKeys[_currentKeyIndex];
    print("DEBUG: Using Key Index: $_currentKeyIndex with Gemini 2.5 Flash");

    try {
      String langName = _getLangName(_selectedLang);
      String prompt = "";
      File? imageToSend;

      if (type == "DIAGNOSIS") {
        prompt = "Act as an agriculture expert. Analyze this plant image. Response in $langName. Output valid JSON only: {\"title\": \"Disease Name\", \"status\": \"Severity\", \"sections\": [{\"heading\": \"Problem\", \"body\": \"Details\"}, {\"heading\": \"Solution\", \"body\": \"Medicine name\"}], \"search_query\": \"medicine for plant disease\"}";
        imageToSend = _selectedImage;
      } else if (type == "SOIL") {
        prompt = "Act as a soil scientist. Analyze this soil image. Response in $langName. Output valid JSON only: {\"title\": \"Soil Type\", \"status\": \"Fertility\", \"sections\": [{\"heading\": \"Analysis\", \"body\": \"Details\"}, {\"heading\": \"Fertilizer\", \"body\": \"Recommendation\"}], \"search_query\": \"organic fertilizer\"}";
        imageToSend = _selectedImage;
      } else if (type == "CHAT") {
        prompt = "Act as an expert. User asks: '$userText'. Response in $langName. Keep it concise. Output valid JSON only: {\"title\": \"Advice\", \"status\": \"Answer\", \"sections\": [{\"heading\": \"Details\", \"body\": \"Answer here\"}], \"search_query\": \"\"}";
        imageToSend = _chatImage; 
      } else if (type == "MARKET") {
        prompt = "Act as market expert. Provide Indian market prices. Response in: $langName. Output valid JSON only: {\"title\": \"Market Rates\", \"status\": \"Live\", \"sections\": [{\"heading\": \"Vegetables\", \"body\": \"Tomato: ₹25/kg, Potato: ₹18/kg\"}, {\"heading\": \"Grains\", \"body\": \"Rice: ₹3200/qt\"}], \"search_query\": \"\"}";
      }

      List<Map<String, dynamic>> parts = [];
      if (imageToSend != null) {
        final bytes = await imageToSend.readAsBytes();
        parts.add({
          "inline_data": {
            "mime_type": "image/jpeg", 
            "data": base64Encode(bytes)
          }
        });
      }
      parts.add({"text": prompt});

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$currentKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"role": "user", "parts": parts}],
          "generationConfig": {
             "maxOutputTokens": 4096, 
             "temperature": 0.4 
          }
        }),
      );

      print("Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] == null) throw "AI Error";
        
        String rawText = data['candidates'][0]['content']['parts'][0]['text'];
        rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
        
        try {
          var parsedResult = jsonDecode(rawText);
          setState(() { _aiResult = parsedResult; _isLoading = false; });
          if (type != "MARKET") _saveToHistory(parsedResult);
          _showResultSheet();
        } catch (e) {
           print("JSON Parse Error: $e");
           throw "Data Error: AI response was incomplete. Try again.";
        }

      } 
      else if (response.statusCode == 429) {
        if (!isRetry) {
           _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
           await Future.delayed(const Duration(seconds: 1));
           await _runGemini(type, userText, isRetry: true);
        } else {
           throw "Busy. Try again later.";
        }
      } else {
        throw "API Error: ${response.statusCode}";
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, color: Colors.grey[300])),
              const SizedBox(height: 20),
              Text(_aiResult?['title'] ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(_aiResult?['status'] ?? "", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
              const Divider(height: 30),
              ...(_aiResult?['sections'] as List? ?? []).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['heading'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(s['body'], style: TextStyle(color: Colors.grey[800], fontSize: 15)),
                  ],
                ),
              )),
              if (_aiResult != null && _aiResult!['search_query'].toString().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse("https://www.google.com/search?tbm=shop&q=${_aiResult!['search_query']}");
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: Text(t('buy')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(t('history'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: _historyLog.isEmpty 
              ? const Center(child: Text("No history found"))
              : ListView.builder(
                  itemCount: _historyLog.length,
                  itemBuilder: (ctx, i) {
                    var item = jsonDecode(_historyLog[i]);
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(item['title']),
                      subtitle: Text(item['saved_date'] ?? ""),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _aiResult = item);
                        _showResultSheet();
                      },
                    );
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)], begin: Alignment.topCenter),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                        onSelected: (val) { if (val == 'hist') _showHistory(); },
                        itemBuilder: (context) => [
                           PopupMenuItem(value: 'hist', child: Text(t('history'))),
                           PopupMenuItem(value: 'about', child: Text(t('about'))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: DropdownButton<String>(
                          value: _selectedLang,
                          dropdownColor: const Color(0xFF2E7D32),
                          icon: const Icon(Icons.language, color: Colors.white),
                          underline: Container(),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (val) => setState(() => _selectedLang = val!),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English')),
                            DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                            // ✅ FIXED: Added Tamil and Kannada
                            DropdownMenuItem(value: 'ta', child: Text('தமிழ்')),
                            DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(t('app_name'), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))
                  ),
                  const SizedBox(height: 20),
                  
                  // WEATHER
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.location_on, color: Colors.white, size: 16),
                              const SizedBox(width: 5),
                              Text(_locationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 5),
                            Text(_temp, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(_weatherDesc, style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        const Icon(Icons.cloud, color: Colors.white, size: 60),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.1, 
                    children: [
                      _actionCard(t('scan'), t('scan_sub'), Icons.camera_alt, Colors.green, () => _pickSourceAndScan("DIAGNOSIS")),
                      _actionCard(t('market'), t('market_sub'), Icons.currency_rupee, Colors.orange, () => _runGemini("MARKET", null)),
                      _actionCard(t('alerts'), t('alerts_sub'), Icons.chat, Colors.purple, _openChatDialog),
                      _actionCard(t('soil'), t('soil_sub'), Icons.grass, Colors.brown, () => _pickSourceAndScan("SOIL")),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _actionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])
          ],
        ),
      ),
    );
  }
}