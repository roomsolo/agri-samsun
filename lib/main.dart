import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomePage(),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? secilenDosya;
  final picker = ImagePicker();
  Interpreter? interpreter;
  FlutterTts flutterTts = FlutterTts();
  String result = "Fotoğraf bekleniyor...";

  List<String> etiketler = [
    "Ayçiçek atığı", 
    "Fındık zürufu", 
    "Hububat", 
    "Sera pancarı", 
    "Tütün sapı"
  ]; 

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  void loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/model.tflite');
      print("Model başarıyla yüklendi!");
    } catch (e) {
      print("Model yükleme hatası: $e");
    }
  }

  void sonucuSesliOku(String metin) async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(metin);
  }

  Float32List imageToByteList(img.Image decodedImage) {
    var convertedBytes = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    
    for (var i = 0; i < 224; i++) {
      for (var j = 0; j < 224; j++) {
        var pixel = decodedImage.getPixel(j, i);
        buffer[pixelIndex++] = pixel.r.toDouble(); 
        buffer[pixelIndex++] = pixel.g.toDouble(); 
        buffer[pixelIndex++] = pixel.b.toDouble();
      }
    }
    return convertedBytes;
  }

  void runModel() async {
    if (secilenDosya == null || interpreter == null) return;

    var imageBytes = await secilenDosya!.readAsBytes();
    img.Image? oriImage = img.decodeImage(imageBytes);
    if (oriImage == null) return;
    
    img.Image resizedImage = img.copyResize(oriImage, width: 224, height: 224);
    var input = imageToByteList(resizedImage).reshape([1, 224, 224, 3]);
    var output = List.filled(1 * etiketler.length, 0.0).reshape([1, etiketler.length]);

    interpreter!.run(input, output);

    double enYuksekPuan = -1.0;
    int enIyiIndeks = 0;
    for (int i = 0; i < etiketler.length; i++) {
      if (output[0][i] > enYuksekPuan) {
        enYuksekPuan = output[0][i];
        enIyiIndeks = i;
      }
    }

    String tespitEdilen = etiketler[enIyiIndeks];
    String yeniSonuc = "Tespit edilen: $tespitEdilen \nDoğruluk: %${(enYuksekPuan * 100).toStringAsFixed(1)}";

    setState(() {
      result = yeniSonuc;
    });

    sonucuSesliOku("Tespit edilen: $tespitEdilen");
  }

  Future pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        secilenDosya = File(picked.path);
        result = "Analiz ediliyor...";
      });
      runModel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tarım AI"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            secilenDosya != null 
              ? Image.file(secilenDosya!, height: 250) 
              : const Icon(Icons.eco, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              result,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Atığı Tara"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}