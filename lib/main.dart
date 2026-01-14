import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://oqscrkdboxffimgjakhh.supabase.co', 
    anonKey: 'sb_publishable_2vgZ6wFdH3r8ZN_ZTXy73Q_EoBrP2v3', 
  );

  runApp(const PlantCareApp());
}

class PlantCareApp extends StatelessWidget {
  const PlantCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF1F8E9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43A047),
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF795548),
        ),
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
  
  String _selectedLang = 'en'; 
  File? _selectedImage; 
  bool _isLoading = false;
  
  // --- CHAT VARIABLES (WhatsApp Style) ---
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _chatSession = []; // Stores {role: 'user'/'ai', text: '...', product: '...'}
  File? _chatImage; 

  Map<String, dynamic>? _aiResult;
  
  // Weather
  String _temp = "--";
  String _weatherDesc = "Loading...";
  String _locationName = "Anekal"; 
  double _currentLat = 12.7109;
  double _currentLng = 77.6966;

  List<String> _historyLog = []; 

  // --- 🔒 SECURE AI ENGINE ---
  Future<void> _runSecureAI(String type, String? userText, File? imageToUse) async {
    // If it's not chat, show global loader
    if (type != "CHAT") setState(() => _isLoading = true);

    try {
      String langName = _getLangName(_selectedLang);
      String systemPrompt = "";
      String finalPromptText = "";

      if (type == "DIAGNOSIS") {
        systemPrompt = "Act as a plant pathologist. Analyze this image. Output ONLY valid JSON: {\"title\": \"Disease Name\", \"status\": \"Severity\", \"sections\": [{\"heading\": \"Problem\", \"body\": \"Short explanation\"}, {\"heading\": \"Cure\", \"body\": \"Medicine name\"}], \"search_query\": \"medicine for plant disease\"}. Response in $langName.";
        finalPromptText = systemPrompt;
      } 
      else if (type == "SOIL") {
        systemPrompt = "Act as a soil scientist. Analyze this soil image. Output ONLY valid JSON: {\"title\": \"Soil Type\", \"status\": \"Fertility Level\", \"sections\": [{\"heading\": \"Analysis\", \"body\": \"Details\"}, {\"heading\": \"Fertilizer\", \"body\": \"Recommendation\"}], \"search_query\": \"organic fertilizer\"}. Response in $langName.";
        finalPromptText = systemPrompt;
      } 
      else if (type == "MARKET") {
        systemPrompt = "Act as a market expert. Provide current market prices for vegetables in $_locationName, India. Response in $langName. Output ONLY valid JSON: {\"title\": \"Market Rates ($_locationName)\", \"status\": \"Live Updates\", \"sections\": [{\"heading\": \"Vegetables\", \"body\": \"Tomato: ₹25/kg, Onion: ₹30/kg\"}, {\"heading\": \"Grains\", \"body\": \"Rice: ₹3500/qt\"}], \"search_query\": \"\"}.";
        finalPromptText = systemPrompt;
      }
      else if (type == "CHAT") {
        // --- 🧠 MEMORY LOGIC ---
        // We construct a history string to send to the AI so it "remembers"
        String historyContext = _chatSession.map((m) => "${m['role'] == 'user' ? 'User' : 'AI'}: ${m['text']}").join("\n");
        
        systemPrompt = """
        You are a helpful agriculture expert friend. 
        HISTORY OF CONVERSATION:
        $historyContext
        
        CURRENT USER QUESTION: '$userText'
        
        INSTRUCTIONS:
        1. Reply in $langName.
        2. IF the user mentions a problem/disease, you MUST recommend a product.
        3. Output ONLY valid JSON: 
        {
          "title": "Chat", 
          "status": "Reply", 
          "sections": [{"heading": "Reply", "body": "Your conversational answer here"}], 
          "search_query": "name of product to buy if needed else empty string"
        }
        """;
        finalPromptText = systemPrompt;
      }

      dynamic finalPayload;

      // Handle Image
      if (imageToUse != null) {
        final bytes = await imageToUse.readAsBytes();
        String base64Image = base64Encode(bytes);
        
        finalPayload = [
          {"text": finalPromptText},
          {
            "inline_data": {
              "mime_type": "image/jpeg",
              "data": base64Image
            }
          }
        ];
      } else {
        finalPayload = finalPromptText;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'ask-gemini',
        body: {'prompt': finalPayload},
      );

      final data = response.data;
      String? rawText = data['answer'];

      if (rawText != null) {
        rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
        var parsedResult = jsonDecode(rawText);
        
        // --- HANDLE CHAT RESPONSE VS STANDARD RESPONSE ---
        if (type == "CHAT") {
           setState(() {
             // Extract the main body text from JSON sections
             String replyText = "";
             if (parsedResult['sections'] != null && (parsedResult['sections'] as List).isNotEmpty) {
               replyText = parsedResult['sections'][0]['body'];
             }

             // Add AI response to the chat session list
             _chatSession.add({
               'role': 'ai',
               'text': replyText,
               'product_query': parsedResult['search_query'] // Store the product link query
             });
             _chatImage = null; // Clear image after sending
           });
           
           // Scroll to bottom
           Future.delayed(const Duration(milliseconds: 100), () {
             if (_scrollController.hasClients) {
               _scrollController.animateTo(
                 _scrollController.position.maxScrollExtent, 
                 duration: const Duration(milliseconds: 300), 
                 curve: Curves.easeOut
               );
             }
           });

        } else {
          // Standard modes (Diagnosis, Soil, Market)
          setState(() { 
            _aiResult = parsedResult; 
            _isLoading = false; 
            _chatImage = null; 
          });
          
          if (type != "MARKET") _saveToHistory(parsedResult);
          _showResultSheet();
        }

      } else {
        throw Exception("Empty response");
      }

    } catch (e) {
      setState(() => _isLoading = false);
      String errorMsg = e.toString();
      if (errorMsg.contains("500")) errorMsg = "Server busy. Try again.";
      
      if (type == "CHAT") {
        setState(() {
          _chatSession.add({'role': 'ai', 'text': "Error: $errorMsg. Please try again.", 'product_query': ""});
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $errorMsg"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- 🌍 DICTIONARY ---
  final Map<String, Map<String, String>> _dict = {
    'en': {'app_name': 'Plant Care', 'scan': 'Scan Crop', 'scan_sub': 'Check Disease', 'soil': 'Soil Health', 'soil_sub': 'Fertility Test', 'market': 'Mandi Prices', 'market_sub': 'Live Rates', 'alerts': 'Ask Expert', 'alerts_sub': 'AI Chat', 'buy': 'Buy Now', 'ask_hint': 'Type a message...', 'history': 'My Scans', 'search_loc': 'Find Village', 'enter_city': 'Village/City Name', 'attach': 'Attach Photo', 'cancel': 'Cancel'},
    'hi': {'app_name': 'पौधा देखभाल', 'scan': 'फसल स्कैन', 'scan_sub': 'रोग जांचें', 'soil': 'मिट्टी जांच', 'soil_sub': 'उर्वरता', 'market': 'मंडी भाव', 'market_sub': 'ताज़ा भाव', 'alerts': 'विशेषज्ञ सलाह', 'alerts_sub': 'AI चैट', 'buy': 'अभी खरीदें', 'ask_hint': 'संदेश लिखें...', 'history': 'पुराने स्कैन', 'search_loc': 'गाँव खोजें', 'enter_city': 'गाँव/शहर का नाम', 'attach': 'फोटो जोड़ें', 'cancel': 'रद्द करें'},
    'ta': {'app_name': 'பயிர் பாதுகாப்பு', 'scan': 'பயிர் ஸ்கேன்', 'scan_sub': 'நோய் அறிதல்', 'soil': 'மண் வளம்', 'soil_sub': 'சத்து ஆய்வு', 'market': 'சந்தை விலை', 'market_sub': 'நேரடி விலை', 'alerts': 'AI உதவி', 'alerts_sub': 'கேள்வி', 'buy': 'வாங்க', 'ask_hint': 'தட்டச்சு செய்க...', 'history': 'வரலாறு', 'search_loc': 'ஊர் தேடுக', 'enter_city': 'ஊர் பெயர்', 'attach': 'படம் சேர்', 'cancel': 'ரத்து'},
    'kn': {'app_name': 'ಸಸ್ಯ ರಕ್ಷಣೆ', 'scan': 'ಬೆಳೆ ಸ್ಕ್ಯಾನ್', 'scan_sub': 'ರೋಗ ಪತ್ತೆ', 'soil': 'ಮಣ್ಣಿನ ಆರೋಗ್ಯ', 'soil_sub': 'ಫಲವತ್ತತೆ', 'market': 'ಮಾರುಕಟ್ಟೆ ದರ', 'market_sub': 'ದರ ಪಟ್ಟಿ', 'alerts': 'AI ಸಲಹೆ', 'alerts_sub': 'ಚಾಟ್ ಮಾಡಿ', 'buy': 'ಖರೀದಿಸಿ', 'ask_hint': 'ಸಂದೇಶ ಟೈಪ್ ಮಾಡಿ...', 'history': 'ಇತಿಹಾಸ', 'search_loc': 'ಊರು ಹುಡುಕಿ', 'enter_city': 'ಊರಿನ ಹೆಸರು', 'attach': 'ಫೋಟೋ ಹಾಕಿ', 'cancel': 'ರದ್ದು'}
  };

  String t(String key) => _dict[_selectedLang]?[key] ?? _dict['en']![key] ?? key;

  String _getLangName(String code) {
    if (code == 'hi') return "Hindi";
    if (code == 'ta') return "Tamil";
    if (code == 'kn') return "Kannada";
    return "English";
  }

  @override
  void initState() {
    super.initState();
    _fetchWeather(_currentLat, _currentLng); 
    _loadHistory(); 
  }

  // --- 📜 HISTORY LOGIC ---
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _historyLog = prefs.getStringList('scan_history_v3') ?? []);
  }

  Future<void> _saveToHistory(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();
    result['saved_date'] = DateTime.now().toString().split('.')[0];
    setState(() => _historyLog.insert(0, jsonEncode(result)));
    await prefs.setStringList('scan_history_v3', _historyLog);
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(t('history'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: _historyLog.isEmpty 
              ? const Center(child: Text("No history yet"))
              : ListView.builder(
                  itemCount: _historyLog.length,
                  itemBuilder: (ctx, i) {
                    var item = jsonDecode(_historyLog[i]);
                    return ListTile(
                      leading: const Icon(Icons.history, color: Colors.green),
                      title: Text(item['title'] ?? "Scan"),
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

  // --- WEATHER ---
  Future<void> _fetchWeather(double lat, double lng) async {
    try {
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current_weather=true');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _temp = "${data['current_weather']['temperature']}°C";
          _weatherDesc = "Live Weather"; 
        });
      }
    } catch (e) { /* Ignore */ }
  }

  Future<void> _searchAndSetLocation(String query) async {
    if (query.isEmpty) return;
    try {
      final url = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$query&count=1&language=en&format=json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          setState(() {
            _locationName = result['name'];
            _currentLat = result['latitude'];
            _currentLng = result['longitude'];
            _weatherDesc = "Updating...";
          });
          _fetchWeather(_currentLat, _currentLng);
        }
      }
    } catch (e) { /* Ignore */ }
  }

  void _showLocationSearchDialog() {
    TextEditingController locController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('search_loc')),
        content: TextField(controller: locController, decoration: InputDecoration(hintText: t('enter_city'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('cancel'))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _searchAndSetLocation(locController.text); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Search", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- UI ACTIONS ---
  Future<void> _pickSourceAndScan(String mode) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 150,
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _iconBtn(Icons.camera_alt, "Camera", () { Navigator.pop(context); _processImage(ImageSource.camera, mode); }),
            _iconBtn(Icons.photo_library, "Gallery", () { Navigator.pop(context); _processImage(ImageSource.gallery, mode); }),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String label, VoidCallback onTap) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      IconButton(onPressed: onTap, icon: Icon(icon, size: 40, color: Colors.green[700])),
      Text(label)
    ]);
  }

  Future<void> _processImage(ImageSource source, String mode) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      if (mode == "CHAT_PICK") {
         setState(() => _chatImage = File(image.path));
      } else {
        setState(() => _selectedImage = File(image.path));
        _runSecureAI(mode, null, _selectedImage);
      }
    }
  }

  // --- 💬 WHATSAPP STYLE CHAT INTERFACE ---
  void _showChatInterface() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      enableDrag: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // This function links the global state to the modal state
            void refresh() => setModalState(() {});

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.9, 
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.green[50], 
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(25))
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.support_agent, color: Colors.green, size: 30),
                          const SizedBox(width: 10),
                          Text(t('alerts'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800])),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                        ],
                      ),
                    ),
                    
                    // Chat Bubble List
                    Expanded(
                      child: _chatSession.isEmpty 
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text("Ask me about plants!", style: TextStyle(color: Colors.grey[500]))
                          ],
                        ))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(15),
                          itemCount: _chatSession.length,
                          itemBuilder: (ctx, i) {
                            final msg = _chatSession[i];
                            final isUser = msg['role'] == 'user';
                            final hasProduct = msg['product_query'] != null && msg['product_query'].toString().isNotEmpty;

                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.all(12),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.green[100] : Colors.grey[100],
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: isUser ? const Radius.circular(15) : Radius.circular(0),
                                    bottomRight: isUser ? Radius.circular(0) : const Radius.circular(15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(msg['text'], style: const TextStyle(fontSize: 15)),
                                    
                                    // --- BUY BUTTON INSIDE CHAT ---
                                    if (hasProduct && !isUser) 
                                      GestureDetector(
                                        onTap: () async {
                                          final url = Uri.parse("https://www.google.com/search?tbm=shop&q=${msg['product_query']}");
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(top: 10),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.shopping_cart, size: 16, color: Colors.orange),
                                              const SizedBox(width: 5),
                                              Text(t('buy'), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ),

                    // Input Area
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
                      child: Row(
                        children: [
                          // Photo Button inside Chat
                          IconButton(
                            icon: Icon(Icons.add_a_photo, color: _chatImage != null ? Colors.green : Colors.grey),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                              if (img != null) {
                                setState(() => _chatImage = File(img.path));
                                refresh(); // Update modal UI
                              }
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: InputDecoration(
                                hintText: t('ask_hint'),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FloatingActionButton(
                            mini: true,
                            backgroundColor: Colors.green,
                            child: const Icon(Icons.send, color: Colors.white),
                            onPressed: () {
                              if (_chatController.text.isEmpty) return;
                              
                              String userMsg = _chatController.text;
                              File? imgToSend = _chatImage;

                              setState(() {
                                // Add user message immediately
                                _chatSession.add({'role': 'user', 'text': userMsg, 'product_query': ""});
                                _chatController.clear();
                                _chatImage = null; // Don't clear immediately, wait for send? No, UI needs clear.
                              });
                              refresh(); // Update modal UI

                              // Call AI
                              _runSecureAI("CHAT", userMsg, imgToSend).then((_) {
                                refresh(); // Update modal UI when AI replies
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
              Text(_aiResult?['title'] ?? "", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[900])),
              Text(_aiResult?['status'] ?? "", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 30),
              ...(_aiResult?['sections'] as List? ?? []).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['heading'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[800])),
                      const SizedBox(height: 5),
                      Text(s['body'], style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              )),
              if (_aiResult?['search_query'].isNotEmpty ?? false)
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse("https://www.google.com/search?tbm=shop&q=${_aiResult!['search_query']}");
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10)]
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle),
                          child: const Icon(Icons.shopping_cart, color: Colors.orange),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('buy'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Text("Find medicine online", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  // --- MAIN UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Header
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _showHistory, 
                        icon: const Icon(Icons.menu, color: Colors.white)
                      ),
                      DropdownButton<String>(
                        value: _selectedLang,
                        dropdownColor: const Color(0xFF2E7D32),
                        icon: const Icon(Icons.language, color: Colors.white),
                        underline: Container(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        onChanged: (val) => setState(() => _selectedLang = val!),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                          DropdownMenuItem(value: 'ta', child: Text('தமிழ்')), 
                          DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')), 
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(t('app_name'), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  
                  const SizedBox(height: 20),

                  // Weather Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0288D1), Color(0xFF29B6F6)]),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          InkWell(
                            onTap: _showLocationSearchDialog,
                            child: Row(children: [
                              const Icon(Icons.location_on, color: Colors.white, size: 16),
                              Text(" $_locationName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.white))
                            ]),
                          ),
                          const SizedBox(height: 5),
                          Text(_temp, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(_weatherDesc, style: const TextStyle(color: Colors.white70)),
                        ]),
                        const Icon(Icons.wb_sunny, color: Colors.yellow, size: 60)
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Action Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.0,
                    children: [
                      _actionCard(t('scan'), t('scan_sub'), Icons.qr_code_scanner, Colors.green, () => _pickSourceAndScan("DIAGNOSIS")),
                      _actionCard(t('soil'), t('soil_sub'), Icons.grass, const Color(0xFF795548), () => _pickSourceAndScan("SOIL")),
                      _actionCard(t('market'), t('market_sub'), Icons.store, Colors.orange, () => _runSecureAI("MARKET", null, null)),
                      // ✅ UPDATED CHAT ACTION
                      _actionCard(t('alerts'), t('alerts_sub'), Icons.support_agent, Colors.blue, _showChatInterface),
                    ],
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.green))),
        ],
      ),
    );
  }

  Widget _actionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}