import 'dart:math';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

abstract class Classifier {
  late Interpreter interpreter;
  late InterpreterOptions _interpreterOptions;
  late List<int> _inputShape;
  late List<int> _outputShape;
  late TensorImage _inputImage;
  late TensorBuffer _outputBuffer;

  late TfLiteType _inputType;
  late TfLiteType _outputType;

  final String _labelsFileName = 'assets/labels.txt';

  final int _labelsLength = 450;

  late var _probabilityProcessor;

  late List<String>? labels = null;

  String get modelName;

  NormalizeOp get preProcessNormalizeOp;
  NormalizeOp get postProcessNormalizeOp;

  Classifier({int? numThreads}) {
    _interpreterOptions = InterpreterOptions();

    if (numThreads != null) {
      _interpreterOptions.threads = numThreads;
    }

    loadModel();
    loadLabels();
  }

  Future<void> loadModel() async {
    try {
      interpreter =
          await Interpreter.fromAsset(modelName, options: _interpreterOptions);
      print('Interpreter Created Successfully');

      _inputShape = interpreter.getInputTensor(0).shape;
      _outputShape = interpreter.getOutputTensor(0).shape;
      _inputType = interpreter.getInputTensor(0).type;
      _outputType = interpreter.getOutputTensor(0).type;

      _outputBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
      _probabilityProcessor =
          TensorProcessorBuilder().add(postProcessNormalizeOp).build();
    } catch (e) {
      print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    }
  }

  Future<void> loadLabels() async {
    labels = await FileUtil.loadLabels(_labelsFileName);
    if (labels!.length == _labelsLength) {
      print('Labels loaded successfully');
    } else {
      print('Unable to load labels');
    }
  }

  TensorImage _preProcess() {
    int cropSize = min(_inputImage.height, _inputImage.width);
    return ImageProcessorBuilder()
        .add(ResizeWithCropOrPadOp(cropSize, cropSize))
        .add(ResizeOp(
            _inputShape[1], _inputShape[2], ResizeMethod.NEAREST_NEIGHBOUR))
        .add(preProcessNormalizeOp)
        .build()
        .process(_inputImage);
  }

  String predict(Image image) {
    final pres = DateTime.now().millisecondsSinceEpoch;
    _inputImage = TensorImage(_inputType);
    _inputImage.loadImage(image);
    _inputImage = _preProcess();
    final pre = DateTime.now().millisecondsSinceEpoch - pres;

    print('Time to load image: $pre ms');

    final runs = DateTime.now().millisecondsSinceEpoch;
    interpreter.run(_inputImage.buffer, _outputBuffer.getBuffer());
    final run = DateTime.now().millisecondsSinceEpoch - runs;

    print('Time to run inference: $run ms');

    Map<String, double> labeledProb = TensorLabel.fromList(
            labels!, _probabilityProcessor.process(_outputBuffer))
        .getMapWithFloatValue();
    final pred = getTopProbability(labeledProb);

    return pred;
  }

  void close() {
    interpreter.close();
  }
}

String getTopProbability(Map<String, double> labeledProb) {
  var val = -100000.000;
  var key;
  labeledProb.forEach((k, v) {
    if (v > val) {
      val = v;
      key = k;
    }
  });
  print(key);
  print(val);
  return key;
}
