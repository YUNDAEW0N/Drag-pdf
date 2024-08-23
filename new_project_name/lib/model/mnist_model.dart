import 'package:tflite/tflite.dart';

class MnistModel {
  Future<void> loadModel() async {
    await Tflite.loadModel(
      model: "assets/mnist_model.tflite",
      labels: "assets/labels.txt",
    );
  }

  Future<List?> predictDigit(String imagePath) async {
    var recognitions = await Tflite.runModelOnImage(
      path: imagePath,
      imageMean: 0.0,
      imageStd: 255.0,
      numResults: 1,
      threshold: 0.5,
      asynch: true,
    );
    return recognitions;
  }

  void dispose() {
    Tflite.close();
  }
}
