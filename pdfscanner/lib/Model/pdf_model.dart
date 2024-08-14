import 'dart:io';

class PdfModel {
  final File file;

  PdfModel(this.file);

  String get fileName => file.path.split('/').last;
}
