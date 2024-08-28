import 'dart:io';

import 'package:image/image.dart' as img;

import 'enums/supported_file_type.dart';

class FileRead {
  File _file;
  String _name;
  img.Image? _image;
  final SupportedFileType _sft;
  final int _size;
  final String _extension;
  String? _ocrText; // OCR 텍스트를 저장할 필드 추가

  FileRead(this._file, this._name, this._image, this._size, this._extension)
      : _sft = SupportedFileTypeExtension.fromString(_extension);

  img.Image? getImage() => _image;

  void setImage(img.Image? image) => _image = image;

  File getFile() => _file;

  void setFile(File newFile) => _file = newFile;

  int getSize() {
    try {
      return _file.lengthSync();
    } catch (error) {
      return _size;
    }
  }

  String getName() => _name;

  void setName(String name) => _name = name;

  String getExtensionName() => _extension;

  SupportedFileType getExtensionType() => _sft;

  // OCR 텍스트를 설정하는 메서드
  void setOcrText(String ocrText) => _ocrText = ocrText;

  // OCR 텍스트를 가져오는 메서드
  String? getOcrText() => _ocrText;

  // 파일로부터 OCR 텍스트를 복구하는 메서드 (추가)
  Future<void> loadOcrTextAsync() async {
    final ocrFilePath = '${_file.path}.ocr.txt';
    if (await File(ocrFilePath).exists()) {
      // 비동기로 파일 존재 여부 확인
      _ocrText = await File(ocrFilePath).readAsString(); // 비동기로 파일 읽기
    }
  }

  @override
  String toString() {
    return "File: $_file, size: ${getSize()}, name: $_name, extension: ${getExtensionType().name}, image-width: ${getImage()?.width}, image-height: ${getImage()?.height}, ocrText: $_ocrText";
  }
}
