import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'service.dart';
import 'package:logger/logger.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  //inicializar el servicio TF antes de ejecutar la app
  WidgetsFlutterBinding.ensureInitialized();
  // Cargar el modelo TF Lite que es el que se va a usar para hacer las predicciones
  final tfService = TFService();
  //asíncrono porque la carga del modelo puede tomar un tiempo, y queremos asegurarnos de que el modelo esté listo antes de que la aplicación intente usarlo.
  await tfService.loadModel();

  runApp(MyApp(tfService: tfService));
}

//stateless porque no va a manejar ningún estado,
//solo va a recibir el servicio TF
//y pasarlo a la pantalla principal
class MyApp extends StatelessWidget {
  final TFService tfService;
  const MyApp({super.key, required this.tfService});

  @override
  //build es el método que construye la interfaz de usuario de la aplicación.
  //Aquí se define el tema, el título y la pantalla principal de la aplicación.
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ML imagenes demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 162, 225, 244),
        ),
        useMaterial3: true,
      ),
      home: ModelScreen(tfService: tfService), //PANTALLA PRINCIPAL
    );
  }
}

//stateful porque va a manejar el estado de la imagen seleccionada,
//el resultado de la predicción y la lista de etiquetas
//cargadas desde el archivo de texto
class ModelScreen extends StatefulWidget {
  final TFService tfService;
  const ModelScreen({super.key, required this.tfService});

  @override
  ModelScreenState createState() => ModelScreenState();
}

//ModelScreenState es la clase que maneja el estado de la pantalla principal.
//extends State<ModelScreen> indica que esta clase es el estado de la pantalla ModelScreen,
//lo que permite que esta clase maneje y actualice la interfaz de usuario en respuesta
// a cambios en el estado, como la selección de una imagen o la ejecución del modelo.
class ModelScreenState extends State<ModelScreen> {
  //Lista de etiquetas que se cargan desde el archivo de texto,
  //cada etiqueta corresponde a una clase que el modelo puede predecir.
  List<String> _labels = [];

  //Variable que almacena el resultado de la predicción, que se muestra en la interfaz de usuario.
  String _output = 'Presionar el botón para ejecutar el modelo';

  //almacena la imagen del usuario que se selecciona desde la galería o se toma con la cámara,
  //esta imagen se pasa al servicio TF para hacer la predicción.
  // tiene ? porque puede ser nula, es decir, al inicio no hay ninguna imagen seleccionada.
  File? _image;

  @override
  //sobreescribe el método initState para cargar las etiquetas desde el archivo de texto cuando se inicializa la pantalla.
  void initState() {
    super.initState();
    _loadLabels();
  }

  //customLogger es una instancia de Logger que se configura para imprimir mensajes de log de manera más legible
  // y colorida, lo que facilita la depuración y el seguimiento de la ejecución del modelo.
  var customLogger = Logger(
    printer: PrettyPrinter(
      methodCount: 2, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
    ),
  );

  //_argMax es una función que toma una lista de valores
  // (en este caso, las probabilidades de cada clase)
  int _argMax(List<double> values) {
    // Esta función encuentra el índice del valor máximo en la lista,
    // lo que corresponde a la clase con la mayor probabilidad según el modelo.
    int maxIndex = 0;
    // Inicializa maxValue con el primer valor de la lista para compararlo con los demás.
    double maxValue = values[0];

    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  //future porque la carga de las etiquetas es una operación asíncrona,
  //ya que implica leer un archivo desde el sistema de archivos del dispositivo,
  //lo que puede tomar un tiempo.

  //aqui va loadLabels que es la función que carga
  // las etiquetas desde el archivo de texto y las almacena en la variable _labels.
  //porque el modelo devuelve un índice que corresponde a una etiqueta,
  //y necesitamos esa lista de etiquetas para mostrar el resultado de
  //la predicción de manera legible para el usuario.
  Future<void> _loadLabels() async {
    //final porque el valor de rawLabels no va a cambiar después de ser asignado,
    //y se asigna el resultado de cargar el archivo de texto 'assets/models/labels.txt'
    //usando rootBundle.loadString, que es una función de Flutter para cargar archivos desde los assets

    //es decir carga el contenido del archivo de texto que contiene las etiquetas de las clases que el modelo puede predecir, y luego divide ese contenido en una lista de etiquetas usando split('\n'),
    //donde cada etiqueta está separada por una nueva línea en el archivo de texto.
    // Finalmente, actualiza el estado de la aplicación para que la lista de etiquetas esté disponible para su uso en la predicción.
    final rawLabels = await rootBundle.loadString('assets/models/labels.txt');
    setState(() {
      _labels = rawLabels.split('\n');
    });
  }

  //_pickImage es una función que se encarga de abrir la galería
  //o la cámara del dispositivo para que el usuario pueda seleccionar o tomar una foto.
  Future<void> _pickImage(ImageSource source) async {
    // Crea una instancia de ImagePicker para acceder a las funciones de selección de imágenes.
    final picker = ImagePicker();
    //pickedFIle es el resultado de la función pickImage,
    //que abre la galería o la cámara según el parámetro source
    //y permite al usuario seleccionar o tomar una foto.
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        // Si el usuario selecciona o toma una foto,
        //se actualiza el estado de la aplicación para almacenar la imagen seleccionada en la variable _image,
        //el nombre de la variable empieza con _ porque es una variable privada,
        // es decir, solo se puede acceder a ella dentro de esta clase.
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
      // Aquí se llama al servicio TF para ejecutar el modelo con la imagen seleccionada.
      //List<double> result es el resultado de la predicción,
      // que es una lista de probabilidades para cada clase que el modelo puede predecir.
      //await widget es necesario porque la ejecución del modelo es una operación asíncrona,
      List<double> result = await widget.tfService.runModel(_image!);

      // Se utiliza _argMax para encontrar el índice de la clase con la mayor probabilidad en el resultado de la predicción.
      final int predictedIndex = _argMax(result);
      // Se obtiene la etiqueta correspondiente al índice de la clase predicha
      //y la confianza (probabilidad) de esa predicción.
      final String predictedLabel = _labels[predictedIndex];
      final double confidence = result[predictedIndex];

      // Se utiliza customLogger para imprimir el resultado de la predicción en la consola de manera legible,
      //lo que facilita la depuración y el seguimiento de la ejecución del modelo.
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
        title: const Text('Reconocedor de Imágenes'),
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
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _image == null ? Colors.grey[200] : null,
                    ),
                    child: _image == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 64,
                                  color: Color.fromARGB(255, 211, 194, 223),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Selecciona o toma una foto',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 132, 132, 132),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Cámara"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                //agregar un botón para "reiniciar" la aplicación, es decir, para limpiar la imagen seleccionada y el resultado de la predicción, y volver al estado inicial de la aplicación.
                const SizedBox(height: 25),
                Align(
                  alignment: Alignment.bottomRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _image = null;
                        _output = 'Presionar el botón para ejecutar el modelo';
                      });
                    },
                    icon: const Icon(Icons.refresh_sharp),
                    label: const Text("Reiniciar"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 152, 184, 202),
                      foregroundColor: const Color.fromARGB(255, 52, 51, 51),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
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
