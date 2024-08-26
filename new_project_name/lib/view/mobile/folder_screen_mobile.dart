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
              leading: Image.asset(
                'assets/images/files/jpg_file.png',
                width: 40.0,
                height: 40.0,
                fit: BoxFit.cover,
              ),
              title: Text(
                file.getName(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle:
                  file.getOcrText() != null && file.getOcrText()!.isNotEmpty
                      ? Text(
                          '계좌 번호: ${file.getOcrText()}',
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      : null,
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20.0,
              ),
              onTap: () async {
                final updatedFile = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentViewerScreen(fileRead: file),
                  ),
                );

                if (updatedFile != null) {
                  files[index] = updatedFile;
                  (context as Element).markNeedsBuild();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
