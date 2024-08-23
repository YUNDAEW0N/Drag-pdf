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
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(8.0),
              leading: Icon(
                Icons.insert_drive_file,
                color: Colors.blueAccent,
                size: 40.0,
              ),
              title: Text(
                file.getName(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Size: ${(file.getFile().lengthSync() / 1024).toStringAsFixed(2)} KB',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20.0,
              ),
              onTap: () {
                print('Selected OCR Text: ${file.getOcrText()}'); // 디버깅용 출력
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentViewerScreen(fileRead: file),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
