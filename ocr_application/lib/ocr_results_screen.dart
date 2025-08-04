import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http; // API çağrıları için bu importu ekleyin

class OCRResultsScreen extends StatefulWidget {
  final File? image; // Kameradan veya galeriden gelen resim
  // extractedText artık öncelikle önceden kaydedilmiş sonuçları görüntülemek içindir,
  // yeni bir resimden ilk OCR işlemi API çağrısı ile yapılacaktır.
  final String extractedText;

  const OCRResultsScreen({
    Key? key,
    this.image,
    this.extractedText = '',
  }) : super(key: key);

  @override
  _OCRResultsScreenState createState() => _OCRResultsScreenState();
}

class _OCRResultsScreenState extends State<OCRResultsScreen> {
  late String _extractedText;
  File? _processedImage; // İşlenmiş görseli saklar
  bool _isLoading = false;
  final TextEditingController _textController = TextEditingController(); // Çıkarılan metnin düzenlenmesini sağlar
  List<Map<String, dynamic>> _savedOCRResults = []; // OCR sonuçlarını saklamak için

  // API bitiş noktası, Python çıktınızdaki doğru IP adresi
  static const String _apiEndpoint = 'http://192.168.1.162:5000/analyze';

  @override
  void initState() {
    super.initState();
    _processedImage = widget.image;
    _extractedText = widget.extractedText; // Kaydedilmiş sonuçları yüklemek için
    _textController.text = _extractedText;

    _loadSavedResults(); // Kullanıcının geçmiş sonuçları görmesi için çağrılıyor

    if (widget.image != null) {
      // Eğer yeni bir resim geçilmişse, OCR'ı API aracılığıyla gerçekleştir
      _performOCRWithApi(widget.image!);
    } else if (widget.extractedText.isNotEmpty) {
      // Eğer sadece extractedText geçilmişse (örn. kaydedilmiş bir sonuçtan), kaydet.
      // Bu, _loadSavedResults zaten doldurduysa gereksiz olabilir.
      _saveOCRResult();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Harici API servisini kullanarak OCR gerçekleştirir.
  Future<void> _performOCRWithApi(File imageFile) async {
    setState(() {
      _isLoading = true;
      _extractedText = 'Metin çıkarılıyor...'; // Anında geri bildirim sağla
      _textController.text = _extractedText;
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiEndpoint));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(responseBody);
        // Python API'niz 'response' anahtarı altında metni döndürüyor
        setState(() {
          _extractedText = data['response'] ?? 'Metin çıkarılamadı.';
          _textController.text = _extractedText;
        });
        _saveOCRResult(); // Yeni OCR sonucunu kaydet
      } else {
        setState(() {
          _extractedText = 'API hatası: ${response.statusCode} - $responseBody';
          _textController.text = _extractedText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR hatası: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _extractedText = 'Bağlantı hatası: $e';
        _textController.text = _extractedText;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API ile iletişim kurulurken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('API Hatası: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // İzin kontrolü
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (API 33) - Medya izinleri
        var status = await Permission.photos.status; // Medya dosyaları için izin
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
        return status.isGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12 (API 30-32) - Harici Depolama Yönetimi
        var status = await Permission.manageExternalStorage.status; // Tüm dosya sistemine geniş izin
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted;
      } else {
        // Android 10 ve altı - Depolama izni
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true; // iOS için veya Android değilse doğru kabul et
  }

  // Güvenli dosya kaydetme dizini
  Future<Directory?> _getSafeDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo; // Cihazın Android sürümünü öğrenir

        if (androidInfo.version.sdkInt >= 30) {
          // Android 11+ için - Önce harici depolamayı dene
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final downloadDir = Directory('${extDir.path}/Download');
            if (!downloadDir.existsSync()) {
              downloadDir.createSync(recursive: true); // Klasör yoksa oluşturuyor
            }
            return downloadDir;
          }
        } else {
          // Android 10 ve altı için klasik Downloads klasörü
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (downloadsDir.existsSync()) {
            return downloadsDir;
          }

          final downloadsDir2 = Directory('/storage/emulated/0/Downloads');
          if (downloadsDir2.existsSync()) {
            return downloadsDir2;
          }
        }
      }

      // Fallback: Uygulama belgeleri dizini
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      print('Dizin hatası: $e');
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> _loadSavedResults() async {
    // Geçmiş OCR kayıtları çekilir
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedData = prefs.getString('ocr_results'); // "ocr_results" anahtarıyla saklanan string veriyi çeker.

      if (savedData != null) {
        final List<dynamic> decodedData = json.decode(savedData);
        setState(() {
          _savedOCRResults = decodedData.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Kaydedilmiş sonuçları yükleme hatası: $e');
    }
  }

  Future<void> _saveOCRResult() async {
    try {
      if (_extractedText.isEmpty || _extractedText == 'Metin çıkarılıyor...' || _extractedText.startsWith('API hatası:') || _extractedText.startsWith('Bağlantı hatası:')) {
        return; // Boş veya hata mesajlarını kaydetme
      }

      final prefs = await SharedPreferences.getInstance();

      final newResult = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': _extractedText,
        'date': DateTime.now().toIso8601String(),
        'imagePath': _processedImage?.path ?? '', // Yalnızca resim varsa yolu kaydet
      };

      _savedOCRResults.insert(0, newResult); // Yeni sonucu listenin başına ekler

      if (_savedOCRResults.length > 50) {
        // Bellekte veri birikmemesi için max 50 kayıt tutar
        _savedOCRResults = _savedOCRResults.take(50).toList();
      }

      final String encodedData = json.encode(_savedOCRResults);
      await prefs.setString('ocr_results', encodedData);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('OCR sonucunu kaydetme hatası: $e');
    }
  }

  void _copyToClipboard() {
    // Metni panoya kopyalar
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metin panoya kopyalandı'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareText() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/shared_text_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(_extractedText);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Metin dosyası hazırlandı: ${file.path}'),
          backgroundColor: Colors.blue,
        ),
      );
      // Gerçek bir uygulamada, burada bir paylaşım sayfasını açmak için `share_plus` gibi bir paket kullanırsınız.
      // Örneğin: Share.shareFiles([file.path], text: 'OCR Metni');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paylaşım hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportToPDF() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // İzin kontrolü
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Depolama izni verilmedi.');
      }

      // Dosya kaydetme dizini
      Directory? directory = await _getSafeDownloadDirectory();

      if (directory == null) {
        throw Exception('Kaydetme klasörü bulunamadı');
      }

      final fileName = 'OCR_Sonuc_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');

      // PDF oluştur
      final pdf = pw.Document();

      // Font yükleme (Türkçe karakter desteği için)
      final fontData = await rootBundle.load("lib/assets/fonts/NotoSans-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Başlık
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'OCR SONUCU',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // Çizgi
              pw.Container(
                height: 2,
                color: PdfColors.grey300,
              ),

              pw.SizedBox(height: 20),

              // Tarih bilgisi
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Tarih: ${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    'Saat: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Çıkarılan metin başlığı
              pw.Text(
                'Çıkarılan Metin:',
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 15),

              // Çıkarılan metin içeriği
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  _extractedText.isEmpty ? 'Metin bulunamadı' : _extractedText,
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 11,
                    lineSpacing: 1.5,
                  ),
                ),
              ),

              pw.SizedBox(height: 30),

              // Alt bilgi
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Bu belge OCR (Optical Character Recognition) teknolojisi ile oluşturulmuştur.',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 10,
                    color: PdfColors.grey600,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // PDF'i kaydet
      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes);

      // Dosyanın gerçekten var olup olmadığını kontrol et
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          final fileSize = await file.length();
          final fileSizeKB = (fileSize / 1024).toStringAsFixed(1);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PDF başarıyla kaydedildi! ($fileSizeKB KB)'),
                  Text('Dosya: $fileName', style: const TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Konum',
                textColor: Colors.white,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Dosya Konumu'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dosya Adı:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SelectableText(fileName),
                          const SizedBox(height: 10),
                          const Text('Klasör:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SelectableText(directory!.path),
                          const SizedBox(height: 10),
                          const Text('Tam Yol:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SelectableText(file.path),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Dosya kaydedilemedi');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF kaydetme hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('PDF dışa aktarma hatası: $e');
    }
  }

  // Word dışa aktarma metodu (basitçe düz metin dosyası olarak dışa aktarır)
  Future<void> _exportToWord() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // İzin kontrolü
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Depolama izni verilmedi.');
      }

      // Dosya kaydetme dizini
      Directory? directory = await _getSafeDownloadDirectory();

      if (directory == null) {
        throw Exception('Kaydetme klasörü bulunamadı');
      }

      final fileName = 'OCR_Sonuc_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');

      final content = '''═══════════════════════════════════════════
                OCR SONUCU
═══════════════════════════════════════════

📅 Tarih: ${DateTime.now().toString().split('.')[0]}
📱 Uygulama: Belge Tarayıcı

─────────────────────────────────────────────
                ÇIKARILAN METİN
─────────────────────────────────────────────

${_extractedText.isEmpty ? 'Metin bulunamadı' : _extractedText}

─────────────────────────────────────────────
⏰ Oluşturulma zamanı: ${DateTime.now()}
═══════════════════════════════════════════''';

      // Dosyayı kaydet
      await file.writeAsString(content, encoding: utf8);

      // Dosyanın gerçekten var olup olmadığını kontrol et
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          final fileSize = await file.length();
          final fileSizeKB = (fileSize / 1024).toStringAsFixed(1);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Metin dosyası başarıyla kaydedildi! ($fileSizeKB KB)'),
                  Text('Dosya: $fileName', style: const TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Konum',
                textColor: Colors.white,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Dosya Konumu'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dosya Adı:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SelectableText(fileName),
                          const SizedBox(height: 10),
                          const Text('Klasör:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SelectableText(directory!.path),
                          const SizedBox(height: 10),
                          const Text('Tam Yol:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SelectableText(file.path),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('Dosya kaydedilemedi');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Metin dosyası kaydetme hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Metin dışa aktarma hatası: $e');
    }
  }

  void _deleteOCRResult(String id) async {
    try {
      _savedOCRResults.removeWhere((result) => result['id'] == id);

      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(_savedOCRResults);
      await prefs.setString('ocr_results', encodedData);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sonuç silindi'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Sonuç silme hatası: $e');
    }
  }

  void _loadOCRResult(Map<String, dynamic> result) {
    setState(() {
      _extractedText = result['text'] ?? '';
      _textController.text = _extractedText;

      if (result['imagePath'] != null && result['imagePath'].isNotEmpty) {
        final imageFile = File(result['imagePath']);
        if (imageFile.existsSync()) {
          _processedImage = imageFile;
        } else {
          _processedImage = null; // Resim dosyası artık yok
        }
      } else {
        _processedImage = null; // Resim yolu mevcut değil
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mevcut çıkarılan metin yoksa ve kaydedilmiş sonuçlar yoksa, boş durumu göster.
    // _extractedText API çağrısı sırasında 'Metin çıkarılıyor...' olabilir, bu yüzden isLoading'i de kontrol et.
    if (_extractedText.isEmpty && _savedOCRResults.isEmpty && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('OCR Sonuçları'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.text_fields,
                size: 100,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              Text(
                'Henüz OCR sonucu yok',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ana sayfadan fotoğraf çekerek başlayın',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Sonuçları'),
        actions: _extractedText.isNotEmpty && !_isLoading ? [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Kopyala',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareText,
            tooltip: 'Paylaş',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pdf') _exportToPDF();
              if (value == 'word') _exportToWord();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('PDF olarak kaydet'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'word',
                child: Row(
                  children: [
                    Icon(Icons.description),
                    SizedBox(width: 8),
                    Text('Metin olarak kaydet'),
                  ],
                ),
              ),
            ],
          ),
        ] : null, // Yüklenirken veya metin yokken eylemleri gizle
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_extractedText), // "Metin çıkarılıyor..." mesajını göster
          ],
        ),
      )
          : (_extractedText.isNotEmpty && !_extractedText.startsWith('API hatası:') && !_extractedText.startsWith('Bağlantı hatası:'))
          ? _buildCurrentResult()
          : _buildSavedResults(),
    );
  }

  Widget _buildCurrentResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_processedImage != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _processedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          const SizedBox(height: 20),

          const Text(
            'Çıkarılan Metin:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              maxLines: null,
              controller: _textController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Çıkarılan metin burada görünecek...',
              ),
              onChanged: (value) {
                _extractedText = value;
              },
            ),
          ),

          const SizedBox(height: 30),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportToPDF,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportToWord,
                  icon: const Icon(Icons.description),
                  label: const Text('Metin'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_savedOCRResults.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _extractedText = '';
                    _textController.clear();
                    _processedImage = null;
                  });
                },
                icon: const Icon(Icons.history),
                label: const Text('Geçmiş Sonuçları Görüntüle'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedResults() {
    if (_savedOCRResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Kayıtlı sonuç bulunamadı',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedOCRResults.length,
      itemBuilder: (context, index) {
        final result = _savedOCRResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              result['text'].toString().length > 50
                  ? '${result['text'].toString().substring(0, 50)}...'
                  : result['text'].toString(),
            ),
            subtitle: Text(result['date'].toString().split('T')[0]),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteOCRResult(result['id']),
            ),
            onTap: () => _loadOCRResult(result),
          ),
        );
      },
    );
  }
}
