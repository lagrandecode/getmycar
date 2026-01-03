import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHelper {
  /// Creates a custom car icon marker for Google Maps
  static Future<BitmapDescriptor> createCarIcon({
    Color color = Colors.red,
    double iconSize = 100.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(iconSize, iconSize);
    
    // Draw a circular background
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1.5,
      borderPaint,
    );
    
    // Draw Uber-style car icon (side view silhouette)
    final carPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Car body - main rectangle (Uber style: wider, lower profile)
    final carBody = Path()
      ..moveTo(size.width * 0.15, size.height * 0.5) // Front bottom
      ..lineTo(size.width * 0.15, size.height * 0.4) // Front top
      ..lineTo(size.width * 0.25, size.height * 0.35) // Windshield start
      ..lineTo(size.width * 0.45, size.height * 0.35) // Windshield end / roof start
      ..lineTo(size.width * 0.65, size.height * 0.35) // Roof continues
      ..lineTo(size.width * 0.75, size.height * 0.4) // Rear windshield start
      ..lineTo(size.width * 0.85, size.height * 0.4) // Rear top
      ..lineTo(size.width * 0.85, size.height * 0.5) // Rear bottom
      ..lineTo(size.width * 0.75, size.height * 0.55) // Rear wheel arch
      ..lineTo(size.width * 0.25, size.height * 0.55) // Front wheel arch
      ..close();
    
    canvas.drawPath(carBody, carPaint);
    
    // Car windows (two windows - Uber style)
    final windowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    
    // Front window
    final frontWindow = Path()
      ..moveTo(size.width * 0.25, size.height * 0.35)
      ..lineTo(size.width * 0.35, size.height * 0.35)
      ..lineTo(size.width * 0.35, size.height * 0.42)
      ..lineTo(size.width * 0.25, size.height * 0.42)
      ..close();
    canvas.drawPath(frontWindow, windowPaint);
    
    // Rear window
    final rearWindow = Path()
      ..moveTo(size.width * 0.55, size.height * 0.35)
      ..lineTo(size.width * 0.65, size.height * 0.35)
      ..lineTo(size.width * 0.75, size.height * 0.4)
      ..lineTo(size.width * 0.65, size.height * 0.42)
      ..lineTo(size.width * 0.55, size.height * 0.42)
      ..close();
    canvas.drawPath(rearWindow, windowPaint);
    
    // Wheels (two circles - Uber style: larger, more prominent)
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // Front wheel
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.55),
      size.width * 0.1,
      wheelPaint,
    );
    
    // Rear wheel
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.55),
      size.width * 0.1,
      wheelPaint,
    );
    
    // Wheel rims (white circles inside wheels - Uber style detail)
    final rimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.55),
      size.width * 0.05,
      rimPaint,
    );
    
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.55),
      size.width * 0.05,
      rimPaint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }
  
  /// Creates a simple colored circle marker (fallback)
  static Future<BitmapDescriptor> createCircleMarker({
    Color color = Colors.blue,
    double iconSize = 50.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(iconSize, iconSize);
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      borderPaint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }
  
  /// Creates a custom marker from an asset image file
  /// 
  /// Place your custom icon at: assets/icon/carIcon.png (or carIcon_red.png, carIcon_black.png)
  /// Will be resized to 158x158px
  /// Format: PNG with transparency
  /// 
  /// For different colors, use separate files:
  /// - carIcon_red.png for red
  /// - carIcon_black.png for black
  static Future<BitmapDescriptor> createCarIconFromAsset({
    String assetPath = 'assets/icon/carIcon.png',
    int targetSize = 158,
    String color = 'default', // 'default', 'red', or 'black'
  }) async {
    // Use color-specific icon file if available
    if (color == 'red' && assetPath == 'assets/icon/carIcon.png') {
      assetPath = 'assets/icon/carIcon_red.png';
    } else if (color == 'black' && assetPath == 'assets/icon/carIcon.png') {
      assetPath = 'assets/icon/carIcon_black.png';
    }
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Decode and resize the image using Flutter's image codec
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetSize,
        targetHeight: targetSize,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Convert back to bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode resized image');
      }
      
      final resizedBytes = byteData.buffer.asUint8List();
      
      return BitmapDescriptor.fromBytes(resizedBytes);
    } catch (e) {
      // If color-specific asset not found, try default carIcon.png
      if (assetPath != 'assets/icon/carIcon.png') {
        try {
          print('⚠️ Color-specific icon not found: $assetPath');
          print('   Trying default carIcon.png...');
          final ByteData data = await rootBundle.load('assets/icon/carIcon.png');
          final Uint8List bytes = data.buffer.asUint8List();
          
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: targetSize,
            targetHeight: targetSize,
          );
          final frame = await codec.getNextFrame();
          final image = frame.image;
          
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) {
            throw Exception('Failed to encode resized image');
          }
          
          final resizedBytes = byteData.buffer.asUint8List();
          return BitmapDescriptor.fromBytes(resizedBytes);
        } catch (e2) {
          print('⚠️ Default car icon also not found');
          print('   Falling back to programmatic icon. Error: $e2');
          // Convert color string to Color
          final iconColor = color == 'black' ? Colors.black : (color == 'red' ? Colors.red : Colors.red);
          return createCarIcon(color: iconColor);
        }
      }
      // If default asset not found, fall back to programmatic icon
      print('⚠️ Custom marker asset not found: $assetPath');
      print('   Falling back to programmatic icon. Error: $e');
      final iconColor = color == 'black' ? Colors.black : (color == 'red' ? Colors.red : Colors.red);
      return createCarIcon(color: iconColor);
    }
  }
}

