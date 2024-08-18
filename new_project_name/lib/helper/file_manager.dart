import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drag_pdf/helper/file_helper.dart';
import 'package:drag_pdf/helper/pdf_helper.dart';
import 'package:drag_pdf/model/file_read.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import '../model/enums/supported_file_type.dart';

class FileManager {
  final List<FileRead> _filesInMemory = [];
  final FileHelper fileHelper;

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
    _uploadFileToServer(localFile.getFile());
  }

  //서버 전송 메서드 추가
  /*-------------------------------------------------------------------------------- */
  Future<void> _uploadFileToServer(File file) async {
    final uri = Uri.parse('http://13.125.47.23:8080/upload');

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

  // Future<FileRead?> scanDocument() async {
  //   FileRead? fileRead;
  //   List<String>? paths = await CunningDocumentScanner.getPictures();
  //   if (paths != null && paths.isNotEmpty) {
  //     final pdf = pw.Document();
  //     File file;
  //     for (String path in paths) {
  //       final image = pw.MemoryImage(
  //         File(path).readAsBytesSync(),
  //       );

  //       pdf.addPage(pw.Page(build: (pw.Context context) {
  //         return pw.Center(
  //           child: pw.Image(image),
  //         );
  //       }));
  //     }
  //     file = File('${fileHelper.localPath}${_nameOfNextFile()}');
  //     await file.writeAsBytes(await pdf.save());

  //     final size = await file.length();
  //     fileRead = FileRead(file, _nameOfNextFile(), null, size, "pdf");
  //     _addSingleFile(fileRead, fileHelper.localPath);
  //   }
  //   return fileRead;
  // }

  Future<FileRead?> scanDocument() async {
    FileRead? fileRead;
    List<String>? paths = await CunningDocumentScanner.getPictures();
    if (paths != null && paths.isNotEmpty) {
      for (String imagePath in paths) {
        // 이미지를 JPG 파일로 저장
        final directory = Directory(fileHelper.localPath);
        final fileName = _nameOfNextFile(value: 1);
        final savePath = path.join(directory.path, '$fileName.jpg');
        final imageFile = File(savePath);

        // 원본 이미지를 로드하여 JPG로 저장
        final image = decodeImage(File(imagePath).readAsBytesSync());
        if (image != null) {
          imageFile.writeAsBytesSync(encodeJpg(image, quality: 85));

          final size = await imageFile.length();
          fileRead = FileRead(imageFile, fileName, image, size, "jpg");
          _addSingleFile(fileRead, fileHelper.localPath);
        } else {
          print('이미지 로드 실패: $imagePath');
        }
      }
    }
    return fileRead;
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
