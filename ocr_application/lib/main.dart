import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'ocr_results_screen.dart';
import 'settings_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  late SharedPreferences _prefs; // Bu nesnenin daha sonra başlatılacağını belirtiyor.
  bool _isLoading = true; // Temanın yüklenip yüklenmediğini belirler

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  _loadTheme() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (mounted) { // setState çağrılmadan önce widget dispose edilmişse, hata olmaması için bu kontrol yapılır.
        setState(() {
          _isDarkMode = _prefs.getBool('dark_mode') ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Tema yükleme hatası: $e');
      if (mounted) { // Hata durumunda dark mode kapalı ve tema yüklenmemiş
        setState(() {
          _isDarkMode = false;
          _isLoading = false;
        });
      }
    }
  }

  // Bu metot settings screen'den çağrılacak
  void updateTheme(bool isDarkMode) {
    if (mounted) {
      setState(() {
        _isDarkMode = isDarkMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'OCR Scanner',
      theme: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
      home: MainScreen(onThemeChanged: updateTheme),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.deepPurple,
      primaryColor: Colors.deepPurple,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: const CardThemeData( // Hata burada düzeltildi
        color: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black87),
        bodyMedium: TextStyle(color: Colors.black87),
        titleLarge: TextStyle(color: Colors.black87),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.deepPurple,
      primaryColor: Colors.deepPurple,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: const CardThemeData( // Hata burada düzeltildi
        color: Color(0xFF1F1F1F),
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const MainScreen({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // AppBar başlığını dinamik olarak döndüren yardımcı metot
  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Ana Sayfa';
      case 1:
        return 'OCR Sonuçları';
      case 2:
        return 'Ayarlar';
      default:
        return 'OCR Scanner'; // Varsayılan başlık
    }
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen();
      case 1:
      // OCRResultsScreen'e hiçbir argüman geçirilmediğinde,
      // kendi içinde kaydedilmiş sonuçları yükleyecektir.
        return OCRResultsScreen();
      case 2:
        return SettingsScreen(onThemeChanged: widget.onThemeChanged);
      default:
        return HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()), // Dinamik başlık
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer Header
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.document_scanner,
                      size: 35,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'OCR Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Belge Tarayıcı',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Ana Sayfa
            ListTile(
              leading: Icon(
                Icons.home,
                color: _currentIndex == 0 ? Theme.of(context).primaryColor : null,
              ),
              title: Text(
                'Ana Sayfa',
                style: TextStyle(
                  color: _currentIndex == 0 ? Theme.of(context).primaryColor : null,
                  fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: _currentIndex == 0,
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () {
                setState(() {
                  _currentIndex = 0;
                });
                Navigator.pop(context);
              },
            ),

            // OCR Sonuçları
            ListTile(
              leading: Icon(
                Icons.text_fields,
                color: _currentIndex == 1 ? Theme.of(context).primaryColor : null,
              ),
              title: Text(
                'OCR Sonuçları',
                style: TextStyle(
                  color: _currentIndex == 1 ? Theme.of(context).primaryColor : null,
                  fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: _currentIndex == 1,
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () {
                setState(() {
                  _currentIndex = 1;
                });
                Navigator.pop(context);
              },
            ),

            const Divider(),

            // Ayarlar
            ListTile(
              leading: Icon(
                Icons.settings,
                color: _currentIndex == 2 ? Theme.of(context).primaryColor : null,
              ),
              title: Text(
                'Ayarlar',
                style: TextStyle(
                  color: _currentIndex == 2 ? Theme.of(context).primaryColor : null,
                  fontWeight: _currentIndex == 2 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: _currentIndex == 2,
              selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () {
                setState(() {
                  _currentIndex = 2;
                });
                Navigator.pop(context);
              },
            ),

            const Divider(),

            // Hakkında
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Hakkında'),
              onTap: () {
                Navigator.pop(context);
                _showAboutDialog();
              },
            ),

            // Yardım
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Yardım'),
              onTap: () {
                Navigator.pop(context);
                _showHelpDialog();
              },
            ),
          ],
        ),
      ),
      body: _getCurrentScreen(),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.document_scanner, color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              const Text('OCR Scanner'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versiyon: 1.0.0'),
              SizedBox(height: 10),
              Text('Bu uygulama fotoğraflarınızı metin formatına dönüştürür.'),
              SizedBox(height: 10),
              Text('Özellikler:'),
              Text('• Kamera ile fotoğraf çekme'),
              Text('• Galeriden resim seçme'),
              Text('• OCR ile metin çıkarma'),
              Text('• PDF ve Metin (eski adıyla Word) dışa aktarma'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.help_outline, color: Theme.of(context).primaryColor),
              const SizedBox(width: 10),
              const Text('Yardım'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nasıl Kullanılır:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildHelpItem('1.', 'Ana sayfada "Kamera ile Çek" veya "Galeriden Seç" butonuna basın'),
                _buildHelpItem('2.', 'Fotoğrafı çekin veya seçin'),
                _buildHelpItem('3.', 'OCR işlemi otomatik olarak başlayacak'),
                _buildHelpItem('4.', 'Sonuçları görüntüleyin ve düzenleyin'),
                _buildHelpItem('5.', 'PDF veya Metin formatında kaydedin'),
                const SizedBox(height: 15),
                const Text(
                  'İpuçları:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _buildHelpItem('•', 'Düz ve iyi aydınlatılmış fotoğraflar çekin'),
                _buildHelpItem('•', 'Metni net ve okunaklı hale getirin'),
                _buildHelpItem('•', 'Gölgeleri ve yansımaları minimize edin'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem(String bullet, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bullet,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
