import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'dart:ui'; // Assurez-vous d'importer ce package
import 'package:checkpoint_app/kernel/controllers/tag_controller.dart';
import 'package:flutter/services.dart'; // Importez ce package pour PluginUtilities

import 'package:checkpoint_app/global/controllers.dart';
import 'package:checkpoint_app/kernel/models/face.dart';
import 'package:checkpoint_app/kernel/services/http_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

import 'database_helper.dart';

/// Preprocesses an image in an isolate.
List<List<List<List<double>>>> processImage(Map<String, dynamic> args) {
  final Uint8List bytes = args['bytes'];
  final int left = args['left'];
  final int top = args['top'];
  final int width = args['width'];
  final int height = args['height'];

  final originalImage = img.decodeImage(bytes);
  if (originalImage == null) return [];

  final cropped = img.copyCrop(originalImage, left, top, width, height);
  final resized = img.copyResizeCropSquare(cropped, 112);

  return [
    List.generate(
      112,
      (y) => List.generate(
        112,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (img.getRed(pixel) - 128) / 128.0,
            (img.getGreen(pixel) - 128) / 128.0,
            (img.getBlue(pixel) - 128) / 128.0,
          ];
        },
      ),
    ),
  ];
}

class FaceRecognitionController extends ChangeNotifier {
  static final FaceRecognitionController _instance =
      FaceRecognitionController._internal();

  factory FaceRecognitionController() {
    return _instance;
  }

  FaceRecognitionController._internal();

  Interpreter? _interpreter;
  bool isModelLoaded = false;
  bool isModelInitializing = false;
  String? modelLoadingError;

  List<FacePicture> faces = [];
  final Map<String, List<double>> _knownFaces = {};

  /// Initializes the model and loads known faces.
  Future<void> initializeModel() async {
    if (isModelLoaded || isModelInitializing) return;
    isModelInitializing = true;

    notifyListeners();

    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/facenet.tflite');
      await DatabaseHelper().init();

      final storedFaces = await DatabaseHelper().getAllFaces();
      faces = storedFaces;
      for (final face in storedFaces) {
        _knownFaces[face.matricule] = face.embedding;
      }

      await addKnownFacesFromRemoteAPI();

      isModelLoaded = true;
      modelLoadingError = null;
    } catch (e) {
      modelLoadingError = "Error loading model: $e";
    } finally {
      isModelInitializing = false;
      notifyListeners();
    }
  }

  /// Adds a face from multiple images, averaging their embeddings.
  Future<void> addKnownFaceFromMultipleImages(
      String matricule, List<XFile> images) async {
    final embeddings = <List<double>>[];

    for (final image in images) {
      final embedding = await getEmbedding(image);
      if (embedding == null) {
        throw Exception("Face not detected in image ${image.name}.");
      }
      embeddings.add(embedding);
    }

    final averagedEmbedding = _averageEmbeddings(embeddings);

    _knownFaces[matricule] = averagedEmbedding;
    await DatabaseHelper().insertFace(
      FacePicture(matricule: matricule, embedding: averagedEmbedding),
    );

    notifyListeners();
  }

  /// Averages multiple embedding vectors.
  List<double> _averageEmbeddings(List<List<double>> embeddings) {
    final result = List.filled(128, 0.0);

    for (final emb in embeddings) {
      for (int i = 0; i < emb.length; i++) {
        result[i] += emb[i];
      }
    }

    for (int i = 0; i < result.length; i++) {
      result[i] /= embeddings.length;
    }

    return result;
  }

  /// Adds known faces from a remote API.
  Future<void> addKnownFacesFromRemoteAPI() async {
    final TagsController tg = Get.put(TagsController());
    tg.isLoading.value = true;
    final agents = await HttpManager.getAllAgents();
    final tempDir = await getTemporaryDirectory();

    for (final item in agents) {
      String? url = item.imagePath;
      final matricule = item.matricule;

      if (_knownFaces.containsKey(matricule)) {
        if (kDebugMode) {
          print("Face for $matricule already exists locally. Skipping.");
        }
        continue;
      }

      url = url!.replaceAll("127.0.0.1", "192.168.4.4");
      try {
        final imageResponse = await http.get(Uri.parse(url));
        if (imageResponse.statusCode != 200) continue;

        final path = "${tempDir.path}/$matricule.jpg";
        final file = File(path)..writeAsBytesSync(imageResponse.bodyBytes);
        final xfile = XFile(file.path);

        final embedding = await getEmbedding(xfile);
        if (embedding == null) {
          if (kDebugMode) print("No face detected for $matricule");
          continue;
        }
        _knownFaces[matricule!] = embedding;
        await DatabaseHelper().insertFace(
          FacePicture(matricule: matricule, embedding: embedding),
        );
        notifyListeners();
      } catch (e) {
        if (kDebugMode) print("Error processing $matricule: $e");
      } finally {
        tg.isLoading.value = false;
      }
    }
  }

  /// Normalizes an input vector.
  List<double>? _normalize(List<double> input) {
    final norm = sqrt(input.fold(0, (sum, val) => sum + val * val));
    return (norm == 0) ? null : input.map((e) => e / norm).toList();
  }

  /// Generates an embedding from an image file.
  Future<List<double>?> getEmbedding(XFile imageFile) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
    );

    final inputImage = InputImage.fromFilePath(imageFile.path);
    final faces = await faceDetector.processImage(inputImage);

    if (faces.isEmpty) return null;

    final face = faces.first.boundingBox;
    final bytes = await imageFile.readAsBytes();

    final input = await compute(processImage, {
      'bytes': bytes,
      'left': face.left.toInt(),
      'top': face.top.toInt(), // Correction ici, face.top est déjà un double
      'width': face.width.toInt(),
      'height': face.height.toInt(),
    });

    if (input.isEmpty) return null;

    final output = List.filled(128, 0.0).reshape([1, 128]);
    _interpreter?.run(input, output);

    return _normalize(List<double>.from(output[0]));
  }

  /// Recognizes a face from a captured image.
  Future<String> recognizeFaceFromImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 60);

    if (image == null) return "Operation cancelled by user";

    tagsController.face.value = image;
    tagsController.isLoading.value = true;
    String result = "Unknown";

    try {
      final receivePort = ReceivePort();
      // Obtenez le token de l'isolate racine
      final RootIsolateToken? rootIsolateToken =
          ServicesBinding.rootIsolateToken;
      if (rootIsolateToken == null) {
        throw Exception("Could not get RootIsolateToken from main isolate.");
      }

      await Isolate.spawn(_recognizeFaceInIsolate, {
        'sendPort': receivePort.sendPort,
        'rootIsolateToken': rootIsolateToken, // Passez le token à l'isolate
      });

      final sendPort = await receivePort.first as SendPort;

      final responsePort = ReceivePort();
      sendPort
          .send({'imagePath': image.path, 'replyPort': responsePort.sendPort});

      final isolateResult = await responsePort.first as Map<String, dynamic>;
      receivePort.close();

      if (isolateResult['error'] != null) {
        if (kDebugMode) print("Isolate error: ${isolateResult['error']}");
        result = "Error during recognition";
      } else {
        result = isolateResult['recognizedFace'] as String;
      }
    } catch (e) {
      if (kDebugMode) print("Recognition error: $e");
      result = "Error during recognition";
    } finally {
      tagsController.isLoading.value = false;
    }

    return result;
  }

  /// Isolate function for face recognition.
  static void _recognizeFaceInIsolate(Map<String, dynamic> message) async {
    final SendPort mainSendPort = message['sendPort'];
    final RootIsolateToken rootIsolateToken = message['rootIsolateToken'];

    // Initialisez le BinaryMessenger avec le token
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    await for (var msg in receivePort) {
      if (msg is Map<String, dynamic>) {
        final String imagePath = msg['imagePath'];
        final SendPort replyPort = msg['replyPort'];

        final FaceRecognitionController controller =
            FaceRecognitionController();
        await controller.initializeModel();

        final imageFile = XFile(imagePath);
        final embedding = await controller.getEmbedding(imageFile);

        if (embedding == null) {
          replyPort.send({'recognizedFace': "Unknown"});
          continue;
        }

        String? closestName;
        double minDistance = double.infinity;

        for (final entry in controller._knownFaces.entries) {
          final distance = controller.euclideanDistance(entry.value, embedding);
          if (distance < minDistance) {
            minDistance = distance;
            closestName = entry.key;
          }
        }
        replyPort.send(
            {'recognizedFace': (minDistance < 1.0) ? closestName! : "Unknown"});
      }
    }
  }

  /// Calculates the Euclidean distance between two vectors.
  double euclideanDistance(List<double> e1, List<double> e2) {
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      final diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}
