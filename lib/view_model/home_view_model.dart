import 'dart:io';

import 'package:drag_pdf/helper/file_manager.dart';
import 'package:drag_pdf/helper/helpers.dart';
import 'package:drag_pdf/model/enums/supported_file_type.dart';
import 'package:drag_pdf/model/file_read.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class HomeViewModel {
  final FileManager _mfl = AppSession.singleton.mfl;

  final List<String> allowedExtensions =
      SupportedFileTypeExtension.namesOfSupportedExtension();

  String invalidFormat = "";
  static const String extensionForbidden = "Extension file forbidden: ";

  Future<void> loadFilesFromStorage(String barcode) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.isEmpty) return;

    List<FileRead> files = [];

    for (int i = 0; i < result.files.length; i++) {
      PlatformFile pickedFile = result.files[i];
      String originalPath = pickedFile.path!;
      String newPath = '${originalPath.substring(0, originalPath.lastIndexOf('/'))}/$barcode-${i + 1}.${pickedFile.extension}';

      File renamedFile = await File(originalPath).rename(newPath);
      FileRead fileRead = await IsolateHelper.createFileRead(renamedFile);
      files.add(fileRead);
    }

    _mfl.addFilesInMemory(files);
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

/*  Future<void> loadImagesFromStorage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    List<FileRead> files =
        await IsolateHelper.createAddMultiplesImagesIsolate(images);
    _mfl.addFilesInMemory(files);
  }*/
  Future<void> loadImagesFromStorage(String barcode) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isEmpty) return;

    List<FileRead> files = [];


    for (int i = 0; i < images.length; i++) {
      XFile image = images[i];
      String newPath = '${image.path.substring(0, image.path.lastIndexOf('/'))}/$barcode-${i + 1}.${image.path.split('.').last}';
      File renamedFile = await File(image.path).rename(newPath);
      FileRead fileRead = await IsolateHelper.createFileRead(renamedFile);
      files.add(fileRead);
    }

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

  Future<FileRead?> scanDocument(String barcode) async {
    return await _mfl.scanDocument(barcode);
  }

  Future<FileRead> generatePreviewPdfDocument() async {
    final lp = AppSession.singleton.fileHelper.localPath;
    final pathFinal = '$lp${Utils.nameOfFinalFile}';
    AppSession.singleton.fileHelper.removeIfExist(pathFinal);
    return await _mfl.generatePreviewPdfDocument(
        pathFinal, Utils.nameOfFinalFile);
  }
}
