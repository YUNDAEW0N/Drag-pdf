import 'package:drag_pdf/helper/file_manager.dart';
import 'package:drag_pdf/helper/dialogs/custom_dialog.dart';
import 'package:drag_pdf/helper/loading.dart';
import 'package:flutter/material.dart';
import 'package:drag_pdf/model/file_read.dart';
import 'package:drag_pdf/view/mobile/document_screen_mobile.dart';
import 'package:drag_pdf/helper/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FolderFilesScreen extends StatelessWidget {
  final List<FileRead> files;
  final String folderName;

  const FolderFilesScreen({required this.files, required this.folderName});

  @override
  Widget build(BuildContext context) {
    final fileManager = AppSession.singleton.mfl;

    return Scaffold(
      appBar: AppBar(
        title: Text(folderName),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // 이전 화면으로 true 값 전달
          },
        ),
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
          final isValidated = fileManager.isImageValidated(file.getName());

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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isValidated
                      ? Colors.black
                      : Colors.red, // Validation 상태에 따라 색상 변경
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
                isValidated
                    ? Icons.check_circle
                    : Icons.error, // Validation 상태에 따른 아이콘
                color: isValidated ? Colors.green : Colors.red,
                size: 24.0,
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentViewerScreen(
                      fileRead: file,
                      isValidated: isValidated,
                    ),
                  ),
                );

                // 수정된 파일 데이터와 Validation 상태를 반영
                if (result != null && result is Map) {
                  final updatedFile = result['fileRead'] as FileRead;
                  final updatedValidationStatus = result['isValidated'] as bool;

                  files[index] = updatedFile;

                  // Validation 상태를 업데이트합니다.
                  fileManager.imageValidationStatus[updatedFile.getName()] =
                      updatedValidationStatus;

                  (context as Element).markNeedsBuild();
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> saveUploadStatus(String folderName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> uploadedFolders = prefs.getStringList('uploadedFolders') ?? [];
    if (!uploadedFolders.contains(folderName)) {
      uploadedFolders.add(folderName);
    }
    await prefs.setStringList('uploadedFolders', uploadedFolders);
  }

  Future<void> _uploadFiles(
      BuildContext context, FileManager fileManager) async {
    // 모든 파일의 validation 상태를 확인
    final hasInvalidFiles =
        files.any((file) => !fileManager.isImageValidated(file.getName()));

    if (hasInvalidFiles) {
      // Validation을 통과하지 못한 파일이 있는 경우
      CustomDialog.showError(
        context: context,
        error: 'Validation Error', // 이 부분에 오류 메시지를 추가
        titleLocalized: '서버 전송 실패',
        subtitleLocalized: 'Validation을 통과하지 못한 파일이 있습니다. 파일을 확인해주세요.',
        buttonTextLocalized: '확인',
      );
      return; // 서버로 전송하지 않고 종료
    }

    // Validation을 모두 통과한 경우에만 업로드 진행
    Loading.show(context);
    try {
      await fileManager.uploadFolderImagesToServer(folderName, folderName);
      await saveUploadStatus(folderName); // 업로드 상태 저장
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
