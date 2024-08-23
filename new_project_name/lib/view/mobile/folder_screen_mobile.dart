import 'package:drag_pdf/model/file_read.dart';
import 'package:drag_pdf/view/mobile/document_screen_mobile.dart';
import 'package:flutter/material.dart';

class FolderFilesScreen extends StatelessWidget {
  final List<FileRead> files;
  final String folderName;

  const FolderFilesScreen({required this.files, required this.folderName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: ListView.builder(
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return ListTile(
            title: Text(file.getName()),
            onTap: () {
              print('Selected OCR Text: ${file.getOcrText()}'); // 디버깅용 출력
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentViewerScreen(fileRead: file),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
