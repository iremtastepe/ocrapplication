import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;

  const SettingsScreen({Key? key, this.onThemeChanged}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _autoSave = true;
  String _selectedLanguage = 'tr';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        _isDarkMode = prefs.getBool('dark_mode') ?? false;
        _autoSave = prefs.getBool('auto_save') ?? true;
        _selectedLanguage = prefs.getString('language') ?? 'tr';
        _isLoading = false;
      });

    } catch (e) {
      print('Settings load error: $e');

      if (!mounted) return;

      setState(() {
        _isDarkMode = false;
        _autoSave = true;
        _selectedLanguage = 'tr';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ayarlar yüklenirken bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveDarkMode(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);

      if (!mounted) return;

      setState(() {
        _isDarkMode = value;
      });

      // Ana tema değişikliğini bildir
      if (widget.onThemeChanged != null) {
        widget.onThemeChanged!(value);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema ayarı kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Save dark mode error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tema ayarı kaydedilemedi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveAutoSave(bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_save', value);

      if (!mounted) return;

      setState(() {
        _autoSave = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Otomatik kaydetme ayarı kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Save auto save error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Otomatik kaydetme ayarı kaydedilemedi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveLanguage(String value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', value);

      if (!mounted) return;

      setState(() {
        _selectedLanguage = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dil ayarı kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Save language error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dil ayarı kaydedilemedi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      default:
        return 'Türkçe';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Ayarlar yükleniyor...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Tema Ayarları Bölümü
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.palette),
                  title: Text(
                    'Tema Ayarları',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text('Aydınlık/Karanlık mod'),
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text('Karanlık Mod'),
                  subtitle: Text('Karanlık temayı etkinleştir'),
                  value: _isDarkMode,
                  onChanged: _saveDarkMode,
                  secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // OCR Ayarları Bölümü
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.text_fields),
                  title: Text(
                    'OCR Ayarları',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text('Metin tanıma ayarları'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.language),
                  title: Text('Dil Seçimi'),
                  subtitle: Text('Mevcut: ${_getLanguageName(_selectedLanguage)}'),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      underline: Container(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          _saveLanguage(newValue);
                        }
                      },
                      items: <String>['tr', 'en', 'de', 'fr']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(_getLanguageName(value)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text('Otomatik Kaydetme'),
                  subtitle: Text('OCR sonuçlarını otomatik kaydet'),
                  value: _autoSave,
                  onChanged: _saveAutoSave,
                  secondary: Icon(Icons.save),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Uygulama Bilgileri Bölümü
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info),
                  title: Text(
                    'Uygulama Bilgileri',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Uygulama Hakkında'),
                  subtitle: Text('Versiyon 1.0.0'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'OCR Scanner',
                      applicationVersion: '1.0.0',
                      applicationIcon: Icon(Icons.document_scanner),
                      children: [
                        Text('Bu uygulama fotoğraflarınızı metin formatına dönüştürür.'),
                        SizedBox(height: 10),
                        Text('Özellikler:'),
                        Text('• Kamera ile fotoğraf çekme'),
                        Text('• Galeriden resim seçme'),
                        Text('• OCR ile metin çıkarma'),
                        Text('• PDF ve Word export'),
                      ],
                    );
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip),
                  title: Text('Gizlilik Politikası'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showPrivacyPolicy();
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.help),
                  title: Text('Yardım'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showHelp();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.privacy_tip, color: Theme.of(context).primaryColor),
              SizedBox(width: 10),
              Text('Gizlilik Politikası'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu uygulama kişisel verilerinizi korur.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('• Çekilen fotoğraflar sadece OCR işlemi için kullanılır'),
                Text('• Verileriniz sadece cihazınızda saklanır'),
                Text('• Hiçbir veri üçüncü taraflarla paylaşılmaz'),
                Text('• İnternet bağlantısı gerektirmez'),
                Text('• Verileriniz güvende tutulur'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.help, color: Theme.of(context).primaryColor),
              SizedBox(width: 10),
              Text('Yardım'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nasıl Kullanılır:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 10),
                _buildHelpItem('1.', 'Ana sayfada "Kamera ile Çek" veya "Galeriden Seç" butonuna basın'),
                _buildHelpItem('2.', 'Fotoğrafı çekin veya seçin'),
                _buildHelpItem('3.', 'OCR işlemi otomatik olarak başlayacak'),
                _buildHelpItem('4.', 'Sonuçları görüntüleyin ve düzenleyin'),
                _buildHelpItem('5.', 'PDF veya Word formatında kaydedin'),
                SizedBox(height: 15),
                Text(
                  'İpuçları:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 10),
                _buildHelpItem('•', 'Düz ve iyi aydınlatılmış fotoğraflar çekin'),
                _buildHelpItem('•', 'Metni net ve okunaklı hale getirin'),
                _buildHelpItem('•', 'Gölgeleri ve yansımaları minimize edin'),
                _buildHelpItem('•', 'Doğru dil seçimini yapın'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem(String bullet, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            child: Text(
              bullet,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}