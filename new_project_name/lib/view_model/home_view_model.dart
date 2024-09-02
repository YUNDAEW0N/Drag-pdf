import 'package:drag_pdf/helper/file_manager.dart';
import 'package:drag_pdf/helper/helpers.dart';
import 'package:drag_pdf/model/enums/supported_file_type.dart';
import 'package:drag_pdf/model/file_read.dart';
import 'package:drag_pdf/view/mobile/folder_screen_mobile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class HomeViewModel {
  final FileManager _mfl = AppSession.singleton.mfl;

  final List<String> allowedExtensions =
      SupportedFileTypeExtension.namesOfSupportedExtension();

  String invalidFormat = "";
  static const String extensionForbidden = "Extension file forbidden: ";

  Future<void> loadFilesFromStorage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    _checkExtensionsFromPickFiles(result);
    _mfl.addMultipleFiles(result?.files ?? [], _mfl.fileHelper.localPath);
  }

  void _checkExtensionsFromPickFiles(FilePickerResult? result) {
    if (result != null) {
      for (PlatformFile file in result.files) {
        final extension = file.extension?.toLowerCase();
        if (!allowedExtensions.contains(extension)) {
          invalidFormat = extension ?? "unknown";
          throw Exception(extensionForbidden + invalidFormat);
        }
      }
    }
  }

  Future<void> loadImagesFromStorage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    List<FileRead> files =
        await IsolateHelper.createAddMultiplesImagesIsolate(images);
    _mfl.addFilesInMemory(files);
  }

  FileManager getMergeableFilesList() => _mfl;

  bool thereAreFilesLoaded() => _mfl.hasAnyFile();

  FileRead removeFileFromDisk(int index) => _mfl.removeFileFromDisk(index);

  void removeFileFromDiskByFile(FileRead file) =>
      _mfl.removeFileFromDiskByFile(file);

  FileRead removeFileFromList(int index) => _mfl.removeFileFromList(index);

  void insertFileIntoList(int index, FileRead file) =>
      _mfl.insertFile(index, file);

  Future<void> rotateImageInMemoryAndFile(FileRead file) async {
    final rotateImage = await IsolateHelper.createRotateIsolate(file);
    file.setImage(rotateImage.getImage());
    await ImageHelper.updateCache(file);
  }

  Future<void> resizeImageInMemoryAndFile(
      FileRead file, int width, int height) async {
    final resizedFile =
        await IsolateHelper.createResizeIsolate(file, width, height);
    file.setImage(resizedFile.getImage());
    await ImageHelper.updateCache(file);
  }

  Future<void> renameFile(FileRead file, String newName) async {
    await _mfl.renameFile(file, newName);
  }

  Future<FileRead?> scanDocument(String qrCode, String affCd) async {
    return await _mfl.scanDocument(qrCode, affCd);
  }

  Future<FileRead> generatePreviewPdfDocument() async {
    final lp = AppSession.singleton.fileHelper.localPath;
    final pathFinal = '$lp${Utils.nameOfFinalFile}';
    AppSession.singleton.fileHelper.removeIfExist(pathFinal);
    return await _mfl.generatePreviewPdfDocument(
        pathFinal, Utils.nameOfFinalFile);
  }

  // 폴더 목록을 불러오는 메서드
  List<String> getFolderNames() {
    return _mfl.loadFolderNames();
  }

  Future<void> openFolder(String folderName, BuildContext context) async {
    final files = await _mfl.loadFilesFromFolder(folderName); // 비동기 파일 로드
    if (files.isNotEmpty) {
      // 폴더 화면이 닫힐 때까지 기다리고, result 값을 받습니다.
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FolderFilesScreen(
            files: files,
            folderName: folderName,
          ),
        ),
      );

      // 폴더 화면이 닫힌 후, result가 true이면 UI를 갱신합니다.
      if (result == true) {
        // HomeScreenMobile에서 setState를 호출하여 UI를 갱신할 수 있도록 함
        if (context.mounted) {
          (context as Element).markNeedsBuild();
        }
      }
    } else {
      // 파일이 없는 경우에 대한 처리
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('폴더에 파일이 없습니다.')),
      );
    }
  }
}
