import 'dart:io';

import 'package:flutter/services.dart';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:drag_pdf/helper/file_helper.dart';
import 'package:drag_pdf/helper/pdf_helper.dart';
import 'package:drag_pdf/model/file_read.dart';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/vision/v1.dart';

import '../model/enums/supported_file_type.dart';

class FileManager {
  final List<FileRead> _filesInMemory = [];
  final FileHelper fileHelper;


  final _scopes = [VisionApi.cloudPlatformScope];

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
      img.Image? image = img.decodeNamedImage(file.name, bytes);
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
      final folderPath = path.join(fileHelper.localPath, qrCode);
      final folder = Directory(folderPath);

      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
        folderFileCounts[qrCode] = 1;
      } else {
        folderFileCounts[qrCode] ??= 1;
      }

      for (String imgPath in paths) {
        // Google Cloud Vision API를 사용한 OCR 인식
        String ocrText = await performGoogleCloudOcr(imgPath);

        final image = img.decodeImage(File(imgPath).readAsBytesSync());

        if (image != null) {
          final fileName = "$qrCode-${folderFileCounts[qrCode]}.jpg";
          final outputFilePath = path.join(folderPath, fileName);

          File(outputFilePath).writeAsBytesSync(img.encodeJpg(image));

          final file = File(outputFilePath);
          final size = await file.length();
          fileRead = FileRead(file, fileName, image, size, "jpg");
          fileRead.setOcrText(ocrText);

          File('${outputFilePath}.ocr.txt').writeAsStringSync(ocrText);

          print('SCANDOCUMENT: $ocrText');
          _addSingleFile(fileRead, folderPath);

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
          final image = img.decodeImage(file.readAsBytesSync());
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

  // Google Cloud Vision API를 사용한 OCR 메서드
  Future<String> performGoogleCloudOcr(String imagePath) async {
    try {
      // rootBundle을 사용하여 JSON 파일 읽기
      String jsonString = await rootBundle
          .loadString('assets/algebraic-envoy-433701-k5-bfaaa577ad0a.json');
      var credentials = ServiceAccountCredentials.fromJson(jsonString);
      var client = await clientViaServiceAccount(credentials, _scopes);

      var vision = VisionApi(client);
      var image = await File(imagePath).readAsBytes();

      var request = BatchAnnotateImagesRequest(
        requests: [
          AnnotateImageRequest(
            image: Image(content: base64Encode(image)),
            features: [Feature(type: 'DOCUMENT_TEXT_DETECTION')],
          ),
        ],
      );

      var response = await vision.images.annotate(request);

      if (response.responses!.isEmpty) {
        throw Exception('Empty response from Vision API');
      }

      // OCR 결과 텍스트 추출
      String ocrResult =
          response.responses!.first.textAnnotations?.first.description ??
              '추출할 텍스트가 없습니다.';

      // 숫자 4자리-숫자 4자리-숫자 4자리 패턴 추출
      final regex = RegExp(r'\b\d{4}-\d{4}-\d{4}\b');
      final matches =
          regex.allMatches(ocrResult).map((match) => match.group(0)).join('\n');

      client.close();

      // 패턴이 존재하지 않는 경우의 메시지 설정
      return matches.isNotEmpty ? matches : '4-4-4 패턴이 없습니다.';
    } catch (e) {
      print('Google Cloud OCR 에러 발생: $e');
      return 'Error performing OCR';
    }
  }

  //--------------------------------------------------------------------------------------

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
