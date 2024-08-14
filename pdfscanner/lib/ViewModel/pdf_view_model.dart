import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:mobilescanner/Model/pdf_model.dart';

class PdfViewModel extends ChangeNotifier {
  File? _selectedImage;
  Rect? _cropRect;
  Offset? _startPosition;
  Offset? _currentPosition;
  List<PdfModel> _pdfFiles = [];

  File? get selectedImage => _selectedImage;
  Rect? get cropRect => _cropRect;
  List<PdfModel> get pdfFiles => _pdfFiles;

  final ImagePicker imagePicker = ImagePicker();

  Future<void> getImageFromGallery() async {
    var img = await imagePicker.pickImage(source: ImageSource.gallery);
    _selectedImage = File(img!.path);
    _cropRect = null;
    notifyListeners();
  }

  Future<void> getImageFromCamera() async {
    var img = await imagePicker.pickImage(source: ImageSource.camera);
    _selectedImage = File(img!.path);
    _cropRect = null;
    notifyListeners();
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);
    final showimage = pw.MemoryImage(_selectedImage!.readAsBytesSync());

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Center(
            child: pw.Image(showimage, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> savePdf() async {
    final pdfData = await _generatePdf(PdfPageFormat.a4);
    final output = await getExternalStorageDirectory();
    final file = File(
        "${output!.path}/scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(pdfData);
    await OpenFile.open(file.path);

    _loadPdfFiles();
  }

  Future<void> _loadPdfFiles() async {
    final output = await getExternalStorageDirectory();
    final dir = Directory(output!.path);
    final List<FileSystemEntity> entities = dir.listSync();
    final List<PdfModel> pdfFiles = [];

    for (FileSystemEntity entity in entities) {
      if (entity is File && entity.path.endsWith('.pdf')) {
        pdfFiles.add(PdfModel(entity));
      }
    }

    _pdfFiles = pdfFiles;
    notifyListeners();
  }

  void onPanStart(DragStartDetails details) {
    _startPosition = details.localPosition;
  }

  void onPanUpdate(DragUpdateDetails details) {
    _currentPosition = details.localPosition;
    _cropRect = Rect.fromPoints(_startPosition!, _currentPosition!);
    notifyListeners();
  }

  void loadInitialData() {
    _loadPdfFiles();
  }
}
