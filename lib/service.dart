import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';

class TFService {
  Interpreter? _interpreter;

  var customLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
    ),
  );

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilenet_v1_1.0_224.tflite',
      );
      customLogger.i('Model was loaded successfully');
      if (_interpreter != null) {
        var inputShape = _interpreter!.getInputTensor(0).shape;
        var outputShape = _interpreter!.getOutputTensor(0).shape;
        customLogger.i('Input shape: $inputShape');
        customLogger.i('Output shape: $outputShape');
        customLogger.i('Interpreter address: ${_interpreter.hashCode}');
      }
    } catch (e) {
      customLogger.i('Error loading model: $e');
    }
  }

  void close() {
    _interpreter?.close();
    customLogger.i('Interpreter closed');
  }

  Future<List<double>> runModel(File imageFile) async {
    if (_interpreter == null) {
      customLogger.e('Interpreter is not initialized. Call loadModel() first.');
      // listado vacío en caso de error
      return [];
    }

    // decodifica la imagen
    img.Image? imageInput = img.decodeImage(imageFile.readAsBytesSync())!;
    img.Image resizedImage = img.copyResize(
      imageInput,
      width: 224,
      height: 224,
    );

    // 3 ==> r g b
    var input = List.generate(
      1 * 224 * 224 * 3,
      (index) => 0.0,
    ).reshape([1, 224, 224, 3]);
    // reshape para tener la imagen en 4 dimensiones
    // asi lo requiere el modelo como entrada

    for (var y = 0; y < resizedImage.height; y++) {
      for (var x = 0; x < resizedImage.width; x++) {
        var pixel = resizedImage.getPixel(x, y);
        // obtener los valores RGB y normalizarlos entre 0 y 1
        var r = pixel.r / 255.0; // 0.15
        var g = pixel.g / 255.0;
        var b = pixel.b / 255.0;

        // asignar los valores al tensor de entrada
        input[0][y][x][0] = r;
        input[0][y][x][1] = g;
        input[0][y][x][2] = b;
      }
    }

    // generamos para la salida una matriz de 1 x 1001
    var output = List.filled(1 * 1001, 0.0).reshape([1, 1001]);

    try {
      _interpreter!.run(input, output);
      customLogger.i('Model inference completed successfully $output');
      //return List<double>.from(output.reshape([1001]));
      return output[0];
    } catch (e) {
      customLogger.e('Error during model inference: $e');
      return [];
    }
  }
}
