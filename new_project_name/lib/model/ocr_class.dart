import 'dart:io';
import 'package:flutter/material.dart';

class RecognizedTextElement {
  final String text;
  final Rect rect;

  RecognizedTextElement({required this.text, required this.rect});
}

class DocumentWithOCROverlay extends StatelessWidget {
  final String imagePath;
  final List<RecognizedTextElement> ocrElements;

  DocumentWithOCROverlay({
    required this.imagePath,
    required this.ocrElements,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document with OCR Overlay'),
      ),
      body: Stack(
        children: [
          Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
          ...ocrElements.map((element) {
            return Positioned(
              left: element.rect.left,
              top: element.rect.top,
              child: Container(
                padding: const EdgeInsets.all(2),
                color: Colors.yellow.withOpacity(0.7),
                child: Text(
                  element.text,
                  style: TextStyle(color: Colors.black, fontSize: 12),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
