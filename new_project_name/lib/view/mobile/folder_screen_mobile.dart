import 'package:drag_pdf/helper/file_manager.dart';
import 'package:drag_pdf/helper/dialogs/custom_dialog.dart';
import 'package:drag_pdf/helper/loading.dart';
import 'package:flutter/material.dart';
import 'package:drag_pdf/model/file_read.dart';
import 'package:drag_pdf/view/mobile/document_screen_mobile.dart';
import 'package:drag_pdf/helper/app_session.dart';

class FolderFilesScreen extends StatelessWidget {
  final List<FileRead> files;
  final String folderName;

  const FolderFilesScreen({required this.files, required this.folderName});

  @override
  Widget build(BuildContext context) {
    // AppSession에서 FileManager 인스턴스를 가져옴
    final fileManager = AppSession.singleton.mfl;

    return Scaffold(
      appBar: AppBar(
        title: Text(folderName),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () async {
              await _uploadFiles(context, fileManager);
            },
          ),
        ],
      ),
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

  Future<void> _uploadFiles(
      BuildContext context, FileManager fileManager) async {
    Loading.show(context);
    try {
      // 서버로 전송
      await fileManager.uploadFolderImagesToServer(
          folderName, folderName); // 여기에 적절한 바코드나 QR 코드 번호를 입력
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지들이 성공적으로 서버로 전송되었습니다.')),
      );
    } catch (error) {
      CustomDialog.showError(
        context: context,
        error: error,
        titleLocalized: '파일 전송 오류',
        subtitleLocalized: error.toString(),
        buttonTextLocalized: '확인',
      );
    } finally {
      Loading.hide();
    }
  }
}
