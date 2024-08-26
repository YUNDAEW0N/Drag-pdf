import 'package:drag_pdf/model/file_read.dart';
import 'package:flutter/material.dart';

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
      // 여기서 Navigator.pop을 호출할 때 수정된 fileRead 객체를 함께 반환합니다.
      Navigator.pop(context, widget.fileRead);
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
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              elevation: 4.0,
              margin: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Image.file(
                  widget.fileRead.getFile(),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // OCR 결과 텍스트 오버레이
          if (!_isEditing)
            GestureDetector(
              onTap: _toggleEditing,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black54.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                margin: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Text(
                    _controller.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    style: const TextStyle(color: Colors.black, fontSize: 20),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
