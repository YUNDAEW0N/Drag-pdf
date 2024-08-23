import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drag_pdf/helper/file_helper.dart';
import 'package:drag_pdf/helper/pdf_helper.dart';
import 'package:drag_pdf/model/file_read.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import '../model/enums/supported_file_type.dart';

class FileManager {
  final List<FileRead> _filesInMemory = [];
  final FileHelper fileHelper;

  // OCR 인식을 위한 TextRecognizer 객체
  final textRecognizer = TextRecognizer();

  FileManager(this.fileHelper);

  bool hasAnyFile() => _filesInMemory.isNotEmpty;

  List<FileRead> getFiles() => _filesInMemory;

  FileRead getFile(int index) => _filesInMemory[index];

  FileRead removeFileFromDisk(int index) {
    fileHelper.removeFile(_filesInMemory[index]);
    return _filesInMemory.removeAt(index);
  }

  void removeFileFromDiskByFile(FileRead file) {
    fileHelper.removeFile(file);
    _filesInMemory.remove(file);
  }

  FileRead removeFileFromList(int index) {
    return _filesInMemory.removeAt(index);
  }

  bool isNameUsedInOtherLoadedFile(String name) =>
      _filesInMemory.indexWhere((element) => element.getName() == name) != -1;

  Future<void> renameFile(FileRead file, String newFileName) async {
    var path = file.getFile().path;
    var lastSeparator = path.lastIndexOf(Platform.pathSeparator);
    var newPath = path.substring(0, lastSeparator + 1) + newFileName;
    final newFile = await file.getFile().rename(newPath);
    file.setFile(newFile);
    file.setName(newFileName);
  }

  void insertFile(int index, FileRead file) =>
      _filesInMemory.insert(index, file);

  int numberOfFiles() => _filesInMemory.length;

  List<FileRead> addMultipleFiles(List<PlatformFile> files, String localPath) {
    for (PlatformFile file in files) {
      final fileRead = FileRead(File(file.path!), _nameOfNextFile(), null,
          file.size, file.extension?.toLowerCase() ?? "");
      _addSingleFile(fileRead, localPath);
    }
    return _filesInMemory;
  }

  Future<List<FileRead>> addMultipleImagesOnDisk(
      List<XFile> files, String localPath, List<String> names) async {
    List<FileRead> finalFiles = [];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final FileRead fileRead;
      final bytes = await file.readAsBytes();
      Image? image = decodeNamedImage(file.name, bytes);
      final size = await file.length();
      final format = FileHelper.singleton.getFormatOfFile(file.path);
      fileRead = FileRead(File(file.path), names[i], image, size, format);
      final fileSaved = saveFileOnDisk(fileRead, localPath);
      finalFiles.add(fileSaved);
    }
    return finalFiles;
  }

  void _addSingleFile(FileRead file, String localPath) {
    final localFile = saveFileOnDisk(file, localPath);
    _filesInMemory.add(localFile);

    // 파일이 추가된 후 서버로 전송
    // _uploadFileToServer(localFile.getFile());
  }

  //서버 전송 메서드 추가
  /*-------------------------------------------------------------------------------- */
  Future<void> _uploadFileToServer(File file) async {
    final uri = Uri.parse('http://3.35.204.106:8080/upload');

    try {
      print('파일 전송 시작: ${path.basename(file.path)}');

      String fileName = path.basename(file.path);

      if (!fileName.contains('.')) {
        fileName = '$fileName.jpeg';
      }
      print('전송할 파일 이름: $fileName');

      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile(
          'uploadFile',
          file.readAsBytes().asStream(),
          await file.length(),
          filename: fileName,
        ));

      final response = await request.send();
      print('서버 응답 상태 코드: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('업로드 성공');
      } else {
        print('업로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('에러 발생: $e');
    }
  }
  /*-------------------------------------------------------------------------------- */

  void addFilesInMemory(List<FileRead> files) {
    for (FileRead file in files) {
      _filesInMemory.add(file);
    }
  }

  FileRead saveFileOnDisk(FileRead file, String localPath) =>
      fileHelper.saveFileInLocalPath(file, localPath);

  void rotateImageInMemoryAndFile(FileRead file) {
    fileHelper.rotateImageInFile(file);
  }

  void resizeImageInMemoryAndFile(FileRead file, int width, int height) {
    fileHelper.resizeImageInFile(file, width, height);
  }

  String _nameOfNextFile({int value = 1}) =>
      "File-${_filesInMemory.length + value}";

  List<String> nextNames(int numberOfFiles) {
    List<String> names = [];
    for (int i = 1; i <= numberOfFiles; i++) {
      names.add(_nameOfNextFile(value: i));
    }
    return names;
  }

  // 바코드별 파일 카운트를 저장하는 맵
  final Map<String, int> folderFileCounts = {};

  Future<FileRead?> scanDocument(String qrCode) async {
    FileRead? fileRead;
    List<String>? paths = await CunningDocumentScanner.getPictures();
    if (paths != null && paths.isNotEmpty) {
      // 바코드 번호를 폴더 이름으로 사용
      final folderPath = path.join(fileHelper.localPath, qrCode);
      final folder = Directory(folderPath);

      // 폴더가 없으면 생성
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
        // 새 폴더일 경우 카운트를 1로 초기화
        folderFileCounts[qrCode] = 1;
      } else {
        // 기존 폴더일 경우 카운트를 가져옴
        folderFileCounts[qrCode] ??= 1;
      }

      for (String imgpath in paths) {
        // OCR 인식
        String ocrText = await _performOCR(imgpath);

        // 이미지 파일을 불러오기
        final image = decodeImage(File(imgpath).readAsBytesSync());

        if (image != null) {
          // 파일 이름을 "바코드번호-카운트.jpg" 형식으로 설정
          final fileName = "$qrCode-${folderFileCounts[qrCode]}.jpg";
          final outputFilePath = path.join(folderPath, fileName);

          // JPG 파일로 저장
          File(outputFilePath).writeAsBytesSync(encodeJpg(image));

          final file = File(outputFilePath);
          final size = await file.length();
          fileRead = FileRead(file, fileName, image, size, "jpg");
          fileRead.setOcrText(ocrText); // OCR 텍스트 설정

          // OCR 텍스트를 파일로 저장
          File('${outputFilePath}.ocr.txt').writeAsStringSync(ocrText);

          print('SCANDOCUMENT: $ocrText');
          _addSingleFile(fileRead, folderPath);

          // 다음 파일을 위해 카운터 증가
          folderFileCounts[qrCode] = folderFileCounts[qrCode]! + 1;
        }
      }
    }
    return fileRead;
  }

  List<FileRead> loadFilesFromFolder(String folderName) {
    final folderPath = path.join(fileHelper.localPath, folderName);
    final folder = Directory(folderPath);
    final files = <FileRead>[];

    if (folder.existsSync()) {
      for (var file in folder.listSync()) {
        if (file is File && file.path.endsWith('.jpg')) {
          final image = decodeImage(file.readAsBytesSync());
          final size = file.lengthSync();
          final fileRead = FileRead(file, path.basename(file.path), image, size,
              path.extension(file.path).substring(1));

          // OCR 텍스트 복구
          fileRead.loadOcrText();

          files.add(fileRead);
        }
      }
    }
    return files;
  }

  // 폴더 목록을 불러오는 메서드
  List<String> loadFolderNames() {
    final directory = Directory(fileHelper.localPath);
    final folders = <String>[];

    if (directory.existsSync()) {
      for (var entity in directory.listSync()) {
        if (entity is Directory) {
          folders.add(path.basename(entity.path));
        }
      }
    }

    return folders;
  }

  final Map<String, String> replacements = {
    'A': '4', 'a': '4', 'B': '8', 'b': '6', //
    'C': '0', 'c': '0', 'D': '0', 'd': '0', //
    'E': '3', 'e': '3', 'F': '7', 'f': '7', //
    'G': '6', 'g': '6', 'h': '6', 'H': '4', //
    'I': '1', 'i': '1', 'l': '1', 'L': '1', //
    '|': '1', '/': '1', 'J': '1', 'j': '1', //
    'K': '1', 'k': '1', 'M': '4', 'm': '4', //
    'N': '7', 'n': '7', 'O': '0', 'o': '0', //
    'P': '9', 'p': '9', 'Q': '0', 'q': '9', //
    'R': '2', 'r': '2', 'S': '5', 's': '5', //
    'T': '7', 't': '7', 'U': '0', 'u': '0', //
    'V': '7', 'v': '7', 'W': '3', 'w': '3', //
    'X': '8', 'x': '8', 'Y': '4', 'y': '4', //
    'Z': '2', 'z': '2', ' ': '', '[': '1', //
  };

  // 후처리 메서드
  String _replaceCharacters(String input) {
    StringBuffer replacedText = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      String char = input[i];
      // replacements 맵에서 해당 문자를 찾고, 없으면 그대로 추가
      replacedText.write(replacements[char] ?? char);
    }

    return replacedText.toString();
  }

  // OCR 인식을 수행하는 메서드
  // Future<String> _performOCR(String imagePath) async {
  //   final inputImage = InputImage.fromFilePath(imagePath);
  //   final recognizedText = await textRecognizer.processImage(inputImage);

  //   StringBuffer ocrText = StringBuffer();

  //   for (TextBlock block in recognizedText.blocks) {
  //     for (TextLine line in block.lines) {
  //       ocrText.writeln(line.text);
  //     }
  //   }

  //   String ocrResult = ocrText.toString().trim();

  //   print("변환 전 OCR 결과: $ocrResult");

  //   // 후처리로 텍스트 변환
  //   String finalResult = _replaceCharacters(ocrResult);

  //   print("최종 OCR 결과: $finalResult");
  //   return finalResult;
  // }

  Future<String> _performOCR(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await textRecognizer.processImage(inputImage);

    StringBuffer ocrText = StringBuffer();

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        ocrText.writeln(line.text);
      }
    }

    String ocrResult = ocrText.toString().trim();

    print("변환 전 OCR 결과: $ocrResult");

    // 후처리로 텍스트 변환
    String processedText = _replaceCharacters(ocrResult);

    // 정규식을 사용하여 숫자 4자리-숫자 4자리-숫자 4자리 패턴만 추출
    final regex = RegExp(r'\b\d{4}-\d{4}-\d{4}\b');
    final matches = regex
        .allMatches(processedText)
        .map((match) => match.group(0))
        .join('\n');

    String finalResult =
        matches.isNotEmpty ? matches : "No valid pattern found";

    print("최종 OCR 결과: $finalResult");
    return finalResult;
  }

  void initializeFolderFileCounts() {
    final directory = Directory(fileHelper.localPath);
    if (directory.existsSync()) {
      for (var entity in directory.listSync()) {
        if (entity is Directory) {
          final folderName = path.basename(entity.path);
          final fileCount = _getFileCountInFolder(entity.path);
          folderFileCounts[folderName] = fileCount + 1; // 다음 파일이 생성될 번호
        }
      }
    }
  }

  int _getFileCountInFolder(String folderPath) {
    final folder = Directory(folderPath);
    if (folder.existsSync()) {
      // '.jpg' 파일만 계산
      return folder
          .listSync()
          .where((entity) => entity.path.endsWith('.jpg'))
          .length;
    }
    return 0;
  }

  Future<FileRead> generatePreviewPdfDocument(
      String outputPath, String nameOutputFile) async {
    List<String> intermediateFiles = [];
    for (FileRead file in _filesInMemory) {
      final FileRead? intermediate = switch (file.getExtensionType()) {
        SupportedFileType.pdf => await PDFHelper.createPdfFromOtherPdf(
            file, '${file.getFile().path}.pdf', '${file.getName()}.pdf'),
        SupportedFileType.png => await PDFHelper.createPdfFromImage(
            file, '${file.getFile().path}.pdf', '${file.getName()}.pdf'),
        SupportedFileType.jpg => await PDFHelper.createPdfFromImage(
            file, '${file.getFile().path}.pdf', '${file.getName()}.pdf'),
        SupportedFileType.jpeg => await PDFHelper.createPdfFromImage(
            file, '${file.getFile().path}.pdf', '${file.getName()}.pdf'),
      };
      intermediateFiles.add(intermediate!.getFile().path);
    }
    FileRead fileRead = await PDFHelper.mergePdfDocuments(
        intermediateFiles, outputPath, nameOutputFile);
    return fileRead;
  }

  @override
  String toString() {
    String text = "-------LOADED FILES -------- \n";
    for (FileRead file in _filesInMemory) {
      text += "$file \n";
    }
    return text;
  }
}
