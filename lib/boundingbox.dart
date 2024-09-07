import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Red Area Detection with Bounding Box',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RedColorDetector(),
    );
  }
}

class RedColorDetector extends StatefulWidget {
  @override
  _RedColorDetectorState createState() => _RedColorDetectorState();
}

class _RedColorDetectorState extends State<RedColorDetector> {
  File? _imageFile;
  img.Image? _processedImage;
  List<double> _redIntensities = [];
  List<double> _redLightness = [];

  final ImagePicker _picker = ImagePicker();
  late Rect _boundingBox; // Bounding box for the largest red area
  bool _hasBoundingBox = false;

  // Function to pick image from gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _processedImage = null;
        _redIntensities = [];
        _redLightness = [];
        _hasBoundingBox = false;
      });
      _processImage(File(pickedFile.path));
    }
  }

  // Convert RGB to HSV
  List<double> _rgbToHsv(int red, int green, int blue) {
    double r = red / 255;
    double g = green / 255;
    double b = blue / 255;

    double max = [r, g, b].reduce((a, b) => a > b ? a : b);
    double min = [r, g, b].reduce((a, b) => a < b ? a : b);
    double delta = max - min;

    double hue = 0.0;
    if (delta != 0) {
      if (max == r) {
        hue = ((g - b) / delta) % 6;
      } else if (max == g) {
        hue = (b - r) / delta + 2;
      } else if (max == b) {
        hue = (r - g) / delta + 4;
      }
      hue *= 60;
    }
    if (hue < 0) hue += 360;

    double saturation = (max == 0) ? 0 : delta / max;
    double value = max;

    return [hue, saturation, value];
  }

  // Convert HSV to HSL
  double _hsvToLightness(double hue, double saturation, double value) {
    double lightness = (value * (1 - saturation / 2));
    return lightness;
  }

  // Function to process the image and detect red areas
  void _processImage(File imageFile) {
    final imageBytes = imageFile.readAsBytesSync();
    final image = img.decodeImage(imageBytes);

    if (image != null) {
      img.Image processedImage = img.Image.from(image);
      List<List<int>> redPixels = [];
      List<double> redIntensities = [];
      List<double> redLightnessValues = [];

      int minX = processedImage.width, minY = processedImage.height;
      int maxX = 0, maxY = 0;

      // Track red pixels and find bounding box
      for (int y = 0; y < processedImage.height; y++) {
        for (int x = 0; x < processedImage.width; x++) {
          final pixel = processedImage.getPixel(x, y);

          final red = pixel.r.toInt();
          final green = pixel.g.toInt();
          final blue = pixel.b.toInt();

          // Convert RGB to HSV
          final hsv = _rgbToHsv(red, green, blue);
          final hue = hsv[0];
          final saturation = hsv[1];
          final value = hsv[2];

          // Check if the pixel is red based on hue and saturation in HSV space
          if ((hue >= 0 && hue <= 10 || hue >= 340 && hue <= 360) &&
              saturation > 0.5 &&
              value > 0.3) {
            // Add pixel coordinates to redPixels list
            redPixels.add([x, y]);

            // Update the bounding box coordinates
            minX = (x < minX) ? x : minX;
            minY = (y < minY) ? y : minY;
            maxX = (x > maxX) ? x : maxX;
            maxY = (y > maxY) ? y : maxY;

            // Calculate red intensity as a percentage
            final redIntensity = (red / 255) * 100;
            redIntensities.add(redIntensity);

            // Convert HSV to HSL to get the lightness percentage
            final lightness = _hsvToLightness(hue, saturation, value) * 100;
            redLightnessValues.add(lightness);

            // Highlight red areas with green color
            processedImage.setPixel(x, y, img.ColorRgb8(0, 255, 0));
          }
        }
      }

      // Calculate bounding box for the largest red area
      if (redPixels.isNotEmpty) {
        _boundingBox = Rect.fromLTRB(
            minX.toDouble(), minY.toDouble(), maxX.toDouble(), maxY.toDouble());
        _hasBoundingBox = true;
      }

      setState(() {
        _processedImage = processedImage;
        _redIntensities = redIntensities;
        _redLightness = redLightnessValues;
      });
    }
  }

  // Function to calculate average red intensity
  double _calculateAverageIntensity() {
    if (_redIntensities.isEmpty) {
      return 0.0;
    }
    return _redIntensities.reduce((a, b) => a + b) / _redIntensities.length;
  }

  // Function to calculate average lightness
  double _calculateAverageLightness() {
    if (_redLightness.isEmpty) {
      return 0.0;
    }
    return _redLightness.reduce((a, b) => a + b) / _redLightness.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Red Color Detection with Bounding Box'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _imageFile == null
                ? Text('No image selected.')
                : _processedImage == null
                    ? Image.file(_imageFile!)
                    : Stack(
                        children: [
                          Image.memory(img.encodeJpg(_processedImage!)),
                          if (_hasBoundingBox)
                            Positioned(
                              left: _boundingBox.left,
                              top: _boundingBox.top,
                              width: _boundingBox.width,
                              height: _boundingBox.height,
                              child: Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.red, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
            SizedBox(height: 20),
            _processedImage != null
                ? Column(
                    children: [
                      Text(
                        'Bounding Box - Width: ${_boundingBox.width.toStringAsFixed(2)}, Height: ${_boundingBox.height.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        'Average Red Intensity: ${_calculateAverageIntensity().toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        'Average Red Lightness: ${_calculateAverageLightness().toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  )
                : Container(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
          ],
        ),
      ),
    );
  }
}
