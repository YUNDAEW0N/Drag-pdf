import 'package:drag_pdf/model/file_read.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class DocumentViewerScreen extends StatefulWidget {
  final FileRead fileRead;

  const DocumentViewerScreen({Key? key, required this.fileRead})
      : super(key: key);

  @override
  _DocumentViewerScreenState createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final ocrText = widget.fileRead.getOcrText();
    print('OCR 결과: $ocrText'); // 디버깅용 출력
    _controller.text = ocrText ?? '';
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveEditedText() async {
    if (_isEditing) {
      setState(() {
        widget.fileRead.setOcrText(_controller.text);
        _toggleEditing();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문서 보기 및 편집'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveEditedText,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 이미지 표시
          Positioned.fill(
            child: Image.file(
              widget.fileRead.getFile(),
              fit: BoxFit.contain, // 이미지가 짤리지 않도록 BoxFit.contain 사용
            ),
          ),
          // OCR 결과 텍스트 오버레이
          if (!_isEditing)
            GestureDetector(
              onTap: _toggleEditing,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                alignment: Alignment.center,
                color: Colors.black54.withOpacity(0.5), // 배경색 투명도 조정
                child: SingleChildScrollView(
                  child: Text(
                    _controller.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      backgroundColor: Colors.transparent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // 텍스트 수정 모드
          if (_isEditing)
            Positioned(
              left: 10,
              right: 10,
              top: 10,
              child: TextField(
                controller: _controller,
                maxLines: null,
                style: const TextStyle(color: Colors.black, fontSize: 20),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
