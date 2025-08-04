import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Bu satırı kaldırıyoruz
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'ocr_results_screen.dart'; // OCRResultsScreen dosyasını import ettiğinizden emin olun

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  // final TextRecognizer _textRecognizer = TextRecognizer(); // Bu satırı kaldırıyoruz

  @override
  void dispose() {
    // _textRecognizer.close(); // Bu satırı kaldırıyoruz
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        var result = await Permission.camera.request();
        if (!result.isGranted) {
          _showErrorDialog('Kamera izni gerekli!');
          return;
        }
      }

      // Android 10 ve altı için depolama izni hala gerekli olabilir
      // Android 11+ için medya izinleri OCRResultsScreen içinde yönetiliyor.
      if (Platform.isAndroid) {
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
      }
    } catch (e) {
      print('İzin hatası: $e');
      _showErrorDialog('İzin kontrolü sırasında bir hata oluştu: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      await _checkPermissions();

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        // OCR işlemi artık OCRResultsScreen içinde yapılacak
        _navigateToOCRResultsScreen(_selectedImage!);
      }
    } catch (e) {
      print('Kamera hatası: $e');
      _showErrorDialog('Kamera hatası: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      // Galeri için depolama izni otomatik olarak istenir, ancak Android 10 ve altı için manuel kontrol iyi olabilir.
      // Android 11+ için medya izinleri ImagePicker tarafından daha iyi yönetilir.
      if (Platform.isAndroid) {
        var photosStatus = await Permission.photos.status;
        if (!photosStatus.isGranted) {
          await Permission.photos.request();
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        // OCR işlemi artık OCRResultsScreen içinde yapılacak
        _navigateToOCRResultsScreen(_selectedImage!);
      }
    } catch (e) {
      print('Galeri hatası: $e');
      _showErrorDialog('Galeri hatası: $e');
    }
  }

  // OCRResultsScreen'e yönlendirme metodu
  void _navigateToOCRResultsScreen(File imageFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OCRResultsScreen(
          image: imageFile,
          // extractedText ve textBlocks artık burada geçirilmiyor,
          // OCRResultsScreen kendi API çağrısını yapacak.
          extractedText: '', // Başlangıçta boş metin gönderiyoruz
        ),
      ),
    );
  }

  // Hata mesajı göstermek için yardımcı metot
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hata'),
          content: Text(message),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo ve başlık
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            child: Icon(
              Icons.document_scanner,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
          ),

          const SizedBox(height: 30),

          Text(
            'Belge Tarayıcı',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            'Fotoğraflarınızı metin formatına dönüştürün',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 50),

          // Kamera Butonu
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: _pickImageFromCamera,
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text(
                'Kamera ile Çek',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Galeri Butonu
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton.icon(
              onPressed: _pickImageFromGallery,
              icon: const Icon(Icons.photo_library, size: 28),
              label: const Text(
                'Galeriden Seç',
                style: TextStyle(fontSize: 18),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Seçilen görsel önizlemesi
          if (_selectedImage != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          if (_selectedImage == null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2),
                color: Colors.grey[50],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: 50,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Seçilen görsel burada görünecek',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
