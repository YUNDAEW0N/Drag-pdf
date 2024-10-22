import 'dart:io';
import 'dart:convert';
import 'package:drag_pdf/api/fileupload.dart';
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

import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/vision/v1.dart';
import '../model/enums/supported_file_type.dart';
import 'package:intl/intl.dart';
import 'package:drag_pdf/api/documentvalidation.dart';

class FileManager {
  final FileUploader fileUploader = FileUploader(); // FileUploader 인스턴스 생성
  final ApiService apiService = ApiService();
  final List<FileRead> _filesInMemory = [];
  final FileHelper fileHelper;
  final _scopes = [VisionApi.cloudPlatformScope];

  final Map<String, bool> folderUploadStatus = {};

  final Map<String, bool> imageValidationStatus =
      {}; // 이미지 파일별 Validation 상태를 저장

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

  //서버 전송 메서드 및 파일 저장 메서드 추가
  /*-------------------------------------------------------------------------------- */
  Future<void> uploadFolderImagesToServer(
      String folderName, String scannedBarcode) async {
    try {
      // 폴더 내의 파일을 모두 로드
      final files = await loadFilesFromFolder(folderName);

      // 서버로 전송할 파일 정보 구성
      Map<String, Map<String, String>> fileInfo = {};
      List<String> filePaths = [];

      for (var file in files) {
        String docNo = file.getOcrText()?.replaceAll('-', '') ?? 'OCR 결과 없음';

        // 파일 정보 구성
        fileInfo[file.getName()] = {'docNo': docNo};

        // filePaths 리스트에 파일 경로 추가
        filePaths.add(file.getFile().path);
      }

      // boxInfo JSON 생성
      final currentDate = DateFormat('yyyyMMdd').format(DateTime.now());
      final boxInfo = {
        'affCd': 'SHB', // 실제 고객사 코드를 입력
        'brCd': '000', // 실제 지점 코드를 입력
        'baseDt': currentDate, // 기준 일자를 YYYYMMDD 형식으로 입력
        'fstRegId': 'superadmin', // 실제 최초 등록자 ID를 입력
        'lstChgId': 'superadmin', // 실제 최종 변경자 ID를 입력
      };

      // 서버로 파일 전송
      final response = await fileUploader.uploadFiles(
        scannedBarcode, // 스캔한 바코드 번호를 shipBoxNo로 사용
        boxInfo,
        fileInfo,
        filePaths,
      );

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);

        // resultCd를 프린트
        print(
            'resultCd: ${jsonResponse['resultCd']}, resultMsg: ${jsonResponse['resultMsg']}');

        print('모든 파일이 서버로 전송되었습니다.');
        folderUploadStatus[folderName] = true; // 성공적으로 전송된 경우에만 상태를 true로 설정
      } else {
        print('파일 업로드 실패: ${response.statusCode}');
        folderUploadStatus[folderName] = false; // 실패 시 상태를 false로 설정
      }
    } catch (e) {
      print('파일 업로드 중 오류 발생: $e');
      folderUploadStatus[folderName] = false; // 예외 발생 시 상태를 false로 설정
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

  Future<FileRead?> scanDocument(String qrCode, String affCd) async {
    FileRead? fileRead;
    List<String>? paths = await CunningDocumentScanner.getPictures();
    if (paths != null && paths.isNotEmpty) {
      final folderPath = path.join(fileHelper.localPath, qrCode);
      final folder = Directory(folderPath);

      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      // 현재 폴더 내에 있는 파일 수를 계산
      int existingFilesCount = folder
          .listSync()
          .where((entity) => entity.path.endsWith('.jpg'))
          .length;

      String currentDate = DateFormat('yyyyMMdd').format(DateTime.now());

      for (int i = 0; i < paths.length; i++) {
        String imgPath = paths[i];
        final image = img.decodeImage(File(imgPath).readAsBytesSync());

        if (image != null) {
          // 고유한 파일 이름 생성
          final fileName =
              '$currentDate${'000'}${(existingFilesCount + i + 1).toString().padLeft(4, '0')}.jpg';
          final outputFilePath = path.join(folderPath, fileName);

          File(outputFilePath).writeAsBytesSync(img.encodeJpg(image));

          final file = File(outputFilePath);
          final size = await file.length();
          final newFileRead = FileRead(file, fileName, image, size, "jpg");

          // OCR 수행 및 결과 저장
          String ocrText = await performGoogleCloudOcrBatch([imgPath])
              .then((res) => res.isNotEmpty ? res[0] : 'OCR 결과 없음');
          newFileRead.setOcrText(ocrText);
          File('${outputFilePath}.ocr.txt').writeAsStringSync(ocrText);
          _filesInMemory.add(newFileRead);

          if (fileRead == null) {
            fileRead = newFileRead;
          }

          // OCR 결과에서 하이픈 제거
          String cleanedDocNo = ocrText.replaceAll('-', '');

          // 서버에 Validation 요청
          final validationResponse =
              await apiService.checkDocumentNumber(cleanedDocNo, affCd);

          print("원장번호 : $cleanedDocNo");

          if (validationResponse['resultCd'] == '01') {
            // Validation 성공
            imageValidationStatus[fileName] = true;
            print('Validation 성공: ${validationResponse['resultMsg']}');
          } else {
            // Validation 실패
            imageValidationStatus[fileName] = false;
            print('Validation 실패: ${validationResponse['resultMsg']}');
          }
        }
      }
    }
    return fileRead;
  }

  // 이미지별 Validation 상태를 반환하는 메서드
  bool isImageValidated(String fileName) {
    return imageValidationStatus[fileName] ?? true;
  }

  Future<List<FileRead>> loadFilesFromFolder(String folderName) async {
    final folderPath = path.join(fileHelper.localPath, folderName);
    final folder = Directory(folderPath);
    final files = <FileRead>[];

    if (folder.existsSync()) {
      final fileList = folder.listSync();

      for (var file in fileList) {
        if (file is File && file.path.endsWith('.jpg')) {
          final bytes = await file.readAsBytes(); // 비동기로 파일 읽기
          final image = img.decodeImage(bytes); // 이미지 디코딩 (이 부분은 동기적)
          final size = await file.length(); // 비동기로 파일 크기 가져오기
          final fileRead = FileRead(
            file,
            path.basename(file.path),
            image,
            size,
            path.extension(file.path).substring(1),
          );

          // OCR 텍스트 복구 (이것도 비동기로 수행)
          await fileRead.loadOcrTextAsync(); // 비동기적으로 OCR 텍스트 읽기

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
  Future<List<String>> performGoogleCloudOcrBatch(
      List<String> imagePaths) async {
    try {
      // rootBundle을 사용하여 JSON 파일 읽기
      String jsonString = await rootBundle
          .loadString('assets/algebraic-envoy-433701-k5-bfaaa577ad0a.json');
      var credentials = ServiceAccountCredentials.fromJson(jsonString);
      var client = await clientViaServiceAccount(credentials, _scopes);

      var vision = VisionApi(client);

      // 여러 이미지를 BatchAnnotateImagesRequest로 처리
      List<AnnotateImageRequest> requests = [];
      for (var imagePath in imagePaths) {
        var imageBytes = await File(imagePath).readAsBytes();
        var request = AnnotateImageRequest(
          image: Image(content: base64Encode(imageBytes)),
          features: [Feature(type: 'DOCUMENT_TEXT_DETECTION')],
        );
        requests.add(request);
      }

      var batchRequest = BatchAnnotateImagesRequest(requests: requests);
      var response = await vision.images.annotate(batchRequest);

      if (response.responses!.isEmpty) {
        throw Exception('Empty response from Vision API');
      }

      // 모든 이미지에 대한 OCR 결과를 저장할 리스트
      List<String> ocrResults = [];

      for (var res in response.responses!) {
        String ocrResult =
            res.textAnnotations?.first.description ?? '추출할 텍스트가 없습니다.';

        // 숫자 4자리-숫자 4자리-숫자 4자리 패턴 추출
        final regex = RegExp(r'\b\d{4}-\d{4}-\d{4}\b');
        final matches = regex
            .allMatches(ocrResult)
            .map((match) => match.group(0))
            .join('\n');
        ocrResults.add(matches.isNotEmpty ? matches : '4-4-4 패턴이 없습니다.');
      }

      client.close();

      return ocrResults;
    } catch (e) {
      print('Google Cloud OCR 에러 발생: $e');
      return List.filled(imagePaths.length, 'Error performing OCR');
    }
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

  Future<void> loadSavedFiles() async {
    try {
      final folderNames = loadFolderNames();
      for (var folderName in folderNames) {
        final files = await loadFilesFromFolder(folderName);
        addFilesInMemory(files);
      }
    } catch (e) {
      print('파일 로드 중 오류 발생: $e');
    }
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
