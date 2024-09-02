import 'package:drag_pdf/model/file_read.dart';
import 'package:flutter/material.dart';
import 'package:drag_pdf/api/documentvalidation.dart'; // ApiService를 가져옵니다.

class DocumentViewerScreen extends StatefulWidget {
  final FileRead fileRead;
  final bool isValidated; // 추가: Validation 상태를 전달받음

  const DocumentViewerScreen({
    Key? key,
    required this.fileRead,
    required this.isValidated, // 추가: Validation 상태를 전달받음
  }) : super(key: key);

  @override
  _DocumentViewerScreenState createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService(); // ApiService 인스턴스 생성
  bool _isEditing = false;
  bool _isValidated = false; // Validation 상태를 저장할 변수

  @override
  void initState() {
    super.initState();
    final ocrText = widget.fileRead.getOcrText();
    _controller.text = ocrText ?? '';
    _isValidated = widget.isValidated; // 초기 Validation 상태 설정
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

      // 수정된 텍스트를 파일에 저장
      await widget.fileRead.saveOcrTextToFile(_controller.text);

      // 수정된 텍스트로 validation 요청
      String cleanedDocNo = _controller.text.replaceAll('-', '');
      final validationResponse = await _apiService.checkDocumentNumber(
        cleanedDocNo,
        'SHB', // 고객사 코드를 여기에 전달
      );

      if (validationResponse['resultCd'] == '01') {
        setState(() {
          _isValidated = true; // Validation 성공 시 상태 업데이트
        });
        print('Validation 성공: ${validationResponse['resultMsg']}');
      } else {
        setState(() {
          _isValidated = false; // Validation 실패 시 상태 업데이트
        });
        print('Validation 실패: ${validationResponse['resultMsg']}');
      }

      // 여기서 Navigator.pop을 호출할 때 수정된 fileRead 객체와 validation 상태를 함께 반환합니다.
      Navigator.pop(
          context, {'fileRead': widget.fileRead, 'isValidated': _isValidated});
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
                  color: _isValidated
                      ? null // Validation 성공 시 기본 이미지 표시
                      : Colors.red.withOpacity(0.5), // Validation 실패 시 빨간색 오버레이
                  colorBlendMode:
                      _isValidated ? null : BlendMode.color, // BlendMode 적용
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
