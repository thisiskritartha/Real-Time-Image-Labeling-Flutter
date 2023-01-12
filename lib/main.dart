import 'package:flutter/foundation.dart';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

late List<CameraDescription> _camera;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _camera = await availableCameras();
  runApp(const MyHomePage());
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController controller;
  String result = 'Result will be shown here.';
  dynamic imageLabeler;
  bool isBusy = false;

  @override
  void initState() {
    super.initState();

    //Initialize labeler
    final ImageLabelerOptions options =
        ImageLabelerOptions(confidenceThreshold: 0.7);
    imageLabeler = ImageLabeler(options: options);

    //Initialize controller
    controller = CameraController(_camera[0], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) => {
            if (isBusy == false) {img = image, doImageLabeling(), isBusy = true}
          });
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('Camera Access Denied.');
            break;
          default:
            print('Other Access Denied');
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  CameraImage? img;
  InputImage getInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in img!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(img!.width.toDouble(), img!.height.toDouble());
    final camera = _camera[0];

    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    // if (imageRotation == null) return;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(img!.format.raw);
    // if (inputImageFormat == null) return null;

    final planeData = img!.planes.map((Plane plane) {
      return InputImagePlaneMetadata(
        bytesPerRow: plane.bytesPerRow,
        height: plane.height,
        width: plane.width,
      );
    }).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );
    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    return inputImage;
  }

  doImageLabeling() async {
    final InputImage inputImage = getInputImage();
    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    result = '';
    for (ImageLabel label in labels) {
      final String text = label.label;
      final int index = label.index;
      final String confidence = (label.confidence.toStringAsFixed(2));
      result += '$text  $confidence\n';
    }
    isBusy = false;
    setState(() {
      result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          Container(
            margin: const EdgeInsets.only(left: 10, bottom: 10),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                result,
                style: const TextStyle(
                  fontSize: 30.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
