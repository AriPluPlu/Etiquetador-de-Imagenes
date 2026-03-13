import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'service.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  //inicializar el servicio TF
  WidgetsFlutterBinding.ensureInitialized();
  final tfService = TFService();
  await tfService.loadModel();

  runApp(MyApp(tfService: tfService));
}

class MyApp extends StatelessWidget {
  final TFService tfService;
  const MyApp({super.key, required this.tfService});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TF Lite Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ModelScreen(tfService: tfService), // 👈 PANTALLA PRINCIPAL
    );
  }
}

class ModelScreen extends StatefulWidget {
  final TFService tfService;
  const ModelScreen({super.key, required this.tfService});

  @override
  ModelScreenState createState() => ModelScreenState();
}

class ModelScreenState extends State<ModelScreen> {
  List<String> _labels = [];

  String _output = 'Presionar el botón para ejecutar el modelo';

  File? _image;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  var customLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
    ),
  );

  int _argMax(List<double> values) {
    int maxIndex = 0;
    double maxValue = values[0];

    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  Future<void> _loadLabels() async {
    final rawLabels = await rootBundle.loadString('assets/models/labels.txt');
    setState(() {
      _labels = rawLabels.split('\n');
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _runModel() async {
    if (_image == null) {
      setState(() {
        _output = 'Por favor, selecciona una imagen primero.';
      });
      return;
    }

    try {
      // var input = List.generate(
      //   1, (i) =>  List.generate(
      //     224, (y) => List.generate(
      //       224, (x) => List.generate(3, (c) => 0.50)
      //     )
      //   )
      // );

      List<double> result = await widget.tfService.runModel(_image!);

      final int predictedIndex = _argMax(result);
      final String predictedLabel = _labels[predictedIndex];
      final double confidence = result[predictedIndex];

      customLogger.i('Result : $result');
      setState(() {
        //_output = result.toString();
        _output =
            'Predicción: $predictedLabel\nConfianza: ${(confidence * 100).toStringAsFixed(2)}%';
      });
    } catch (e) {
      setState(() {
        _output = 'Error al ejecutar el modelo: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconocimiento de Imágenes'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    height: 250,
                    width: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _image == null ? Colors.grey[200] : null,
                    ),
                    child: _image == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 64, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Selecciona o toma una foto', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_image!, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Galería"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Cámara"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _runModel,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Analizar Imagen"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _output,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
