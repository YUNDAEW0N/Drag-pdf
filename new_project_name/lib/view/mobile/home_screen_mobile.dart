import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart' as pdf_render;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drag_pdf/common/colors/colors_app.dart';
import 'package:drag_pdf/common/localization/localization.dart';
import 'package:drag_pdf/components/components.dart';
import 'package:drag_pdf/model/enums/loader_of.dart';
import 'package:go_router/go_router.dart';

import '../../helper/dialogs/custom_dialog.dart';
import '../../helper/helpers.dart';
import '../../view_model/home_view_model.dart';

class HomeScreenMobile extends StatefulWidget {
  const HomeScreenMobile({super.key});

  @override
  State<HomeScreenMobile> createState() => _HomeScreenMobileState();
}

class _HomeScreenMobileState extends State<HomeScreenMobile>
    with WidgetsBindingObserver {
  final HomeViewModel viewModel = HomeViewModel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        Utils.printInDebug(Localization.of(context).string(
            'the_app_did_enter_in_foreground')); // The app did enter in foreground
        break;
      case AppLifecycleState.inactive:
        Utils.printInDebug(Localization.of(context)
            .string('the_app_is_minimize')); // The app is minimize
        break;
      case AppLifecycleState.hidden:
        Utils.printInDebug(Localization.of(context)
            .string('the_app_is_hidden')); // The app is hidden
        break;
      case AppLifecycleState.paused:
        Utils.printInDebug(Localization.of(context).string(
            'the_app_just_went_into_background')); // The app just went into background
        break;
      case AppLifecycleState.detached:
        Utils.printInDebug(Localization.of(context)
            .string('the_app_is_going_to_close')); // The app is going to close
        break;
    }
  }

  Future<void> loadFilesOrImages(LoaderOf from) async {
    setState(() {
      Loading.show();
    });
    try {
      switch (from) {
        case LoaderOf.imagesFromGallery:
          await viewModel.loadImagesFromStorage();
        case LoaderOf.filesFromFileSystem:
          await viewModel.loadFilesFromStorage();
      }
    } catch (error) {
      final subtitle =
          error.toString().contains(HomeViewModel.extensionForbidden)
              ? "forbidden_file_error_subtitle"
              : "read_file_error_subtitle";
      if (!mounted) return; // check "mounted" property
      CustomDialog.showError(
          context: context,
          error: error,
          titleLocalized: 'read_file_error_title',
          subtitleLocalized: subtitle,
          buttonTextLocalized: 'accept');
    } finally {
      setState(() {
        Loading.hide();
        Utils.printInDebug(viewModel.getMergeableFilesList());
      });
    }
  }

  // Future<List<File>> convertPdfToImages(File pdfFile) async {
  //   final pdfDoc = await pdf_render.PdfDocument.openFile(pdfFile.path);
  //   List<File> images = [];

  //   for (int i = 1; i <= pdfDoc.pageCount; i++) {
  //     final page = await pdfDoc.getPage(i);
  //     final pdfImage = await page.render();

  //     // 이미지 생성 및 확인
  //     final image = img.Image.fromBytes(
  //       width: pdfImage.width,
  //       height: pdfImage.height,
  //       bytes: pdfImage.pixels.buffer,
  //     );

  //     print(image);
  //     if (image == null) {
  //       print('이미지 변환 실패: 페이지 $i');
  //       continue;
  //     }

  //     // 이미지 파일로 저장
  //     final directory = await getTemporaryDirectory();
  //     final imagePath = path.join(directory.path, 'page_$i.jpg');
  //     final imageFile = File(imagePath)
  //       ..writeAsBytesSync(img.encodeJpg(image, quality: 85));

  //     // 이미지가 제대로 저장되었는지 확인
  //     print('이미지 파일 경로: $imagePath');
  //     print('파일 존재 여부: ${imageFile.existsSync()}');
  //     print('파일 크기: ${await imageFile.length()} 바이트');

  //     final reloadedImage = img.decodeImage(imageFile.readAsBytesSync());
  //     if (reloadedImage != null) {
  //       print('이미지 파일이 성공적으로 로드되었습니다.');
  //     } else {
  //       print('이미지 파일 로드 실패.');
  //     }

  //     images.add(imageFile);
  //   }

  //   return images;
  // }

  // Future<void> uploadFileToServer(File file) async {
  //   if (file.path.endsWith('.pdf')) {
  //     final images = await convertPdfToImages(file);
  //     for (File imageFile in images) {
  //       await _uploadSingleFileToServer(imageFile);
  //     }
  //   } else {
  //     await _uploadSingleFileToServer(file);
  //   }
  // }

  // Future<void> _uploadSingleFileToServer(File file) async {
  //   final uri = Uri.parse('http://13.125.47.23:8080/upload');

  //   try {
  //     print('파일 전송 시작');
  //     print('파일 이름: ${path.basename(file.path)}');

  //     final reloadedImage = img.decodeImage(bytes);
  //     if (reloadedImage != null) {
  //       print('전송할 파일이 유효한 이미지입니다.');
  //     } else {
  //       print('전송할 파일이 유효한 이미지가 아닙니다.');
  //       return; // 이미지가 아닌 경우 전송하지 않음
  //     }

  //     final request = http.MultipartRequest('POST', uri)
  //       ..files.add(http.MultipartFile.fromBytes(
  //         'uploadFile',
  //         bytes,
  //         filename: path.basename(file.path),
  //         contentType: MediaType('image', 'jpeg'),
  //       ));

  //     final response = await request.send();
  //     print('서버 응답 상태 코드: ${response.statusCode}');
  //     if (response.statusCode == 200) {
  //       print('업로드 성공');
  //     } else {
  //       print('업로드 실패: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('에러 발생: $e');
  //   }
  // }

  //서버 전송 메서드 추가
  /*-------------------------------------------------------------------------------- */
  Future<void> uploadFileToServer(File file) async {
    final uri = Uri.parse('http://13.125.47.23:8080/upload');

    try {
      print('파일 전송 시작');

      String fileName = path.basename(file.path);

      // 파일이 올바른지 다시 확인
      final bytes = await file.readAsBytes();

      // 첫 몇 바이트를 출력하여 파일 형식을 확인
      print('파일의 첫 10 바이트: ${bytes.sublist(0, 10)}');

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
      print('헤더: ${request.headers}');

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

  Future<void> scanImages() async {
    try {
      context.pop('Scan');
      final fileread = await viewModel.scanDocument();
      if (fileread != null) {
        final file = fileread.getFile();
        final filename = fileread.getName();
        setState(() {
          Utils.printInDebug("Document Scanned: $filename");
        });
        print('서버 전송 시도.');
        await uploadFileToServer(file); // 서버 전송 시도
      }
    } catch (error) {
      if (!mounted) return; // check "mounted" property
      CustomDialog.showError(
          context: context,
          error: error,
          titleLocalized: 'read_file_error_title',
          subtitleLocalized: 'scan_file_error_subtitle',
          buttonTextLocalized: 'accept');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Loading.isPresented
          ? const LoadingScreen()
          : Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(Localization.of(context).string('drag_pdf')),
                actions: [
                  IconButton(
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: Text(Localization.of(context)
                            .string('choose_an_option')),
                        // Choose an option
                        content: Text(Localization.of(context)
                            .string('content_home_screen_dialog')),
                        // 'Do you want to load the file(s) from disk or from the document scanner?'
                        actions: [
                          TextButton(
                            onPressed: () {
                              context.pop();
                              FileDialog.add(
                                  context: context,
                                  loadImageFromGallery: () async =>
                                      await loadFilesOrImages(
                                          LoaderOf.imagesFromGallery),
                                  loadFileFromFileSystem: () async =>
                                      await loadFilesOrImages(
                                          LoaderOf.filesFromFileSystem));
                            },
                            child: Text(Localization.of(context)
                                .string('load')), // LOAD
                          ),
                          TextButton(
                            onPressed: () async => await scanImages(),
                            child: Text(Localization.of(context)
                                .string('scan')), // SCAN
                          ),
                          TextButton(
                            onPressed: () => context.pop('Cancel'),
                            child: Text(
                              Localization.of(context)
                                  .string('cancel'), // Cancel
                              style:
                                  const TextStyle(color: ColorsApp.kMainColor),
                            ),
                          )
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.add),
                  )
                ],
              ),
              body: viewModel.thereAreFilesLoaded()
                  ? ReorderableListView.builder(
                      proxyDecorator: (child, index, animation) =>
                          ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                  Colors.blueAccent.withOpacity(0.2),
                                  BlendMode.srcATop),
                              child: child),
                      itemCount:
                          viewModel.getMergeableFilesList().numberOfFiles(),
                      padding: const EdgeInsets.all(8),
                      onReorderStart: (int value) =>
                          HapticFeedback.mediumImpact(),
                      itemBuilder: (context, position) {
                        final file =
                            viewModel.getMergeableFilesList().getFile(position);
                        return Dismissible(
                          key: Key("${file.hashCode}"),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) async {
                            viewModel.removeFileFromDisk(position);
                            setState(() {
                              // Then show a snackbar.
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${Localization.of(context).string('removed_toast')} ${file.getName()}'),
                                ),
                              );
                            });
                          },
                          background: Container(
                            color: ColorsApp.red,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 30),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: ColorsApp.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: FileRow(
                            file: file,
                            removeButtonPressed: () {
                              setState(() {
                                viewModel.removeFileFromDiskByFile(file);
                              });
                            },
                            rotateButtonPressed: () async {
                              setState(() {
                                Loading.show();
                              });
                              await viewModel.rotateImageInMemoryAndFile(file);
                              setState(() {
                                Loading.hide();
                              });
                            },
                            resizeButtonPressed: (int width, int height) async {
                              setState(() {
                                Loading.show();
                              });
                              await viewModel.resizeImageInMemoryAndFile(
                                  file, width, height);
                              setState(() {
                                Loading.hide();
                              });
                            },
                            renameButtonPressed: (String name) async {
                              await viewModel.renameFile(file, name);
                              setState(() {
                                Utils.printInDebug("Renamed File: $file");
                              });
                            },
                          ),
                        );
                      },
                      onReorder: (int oldIndex, int newIndex) {
                        if (newIndex > oldIndex) {
                          newIndex = newIndex - 1;
                        }
                        setState(() {
                          final element =
                              viewModel.removeFileFromList(oldIndex);
                          viewModel.insertFileIntoList(newIndex, element);
                        });
                      },
                    )
                  : Center(
                      child: Image.asset('assets/images/files/file.png'),
                    ),
              floatingActionButton: Visibility(
                visible: viewModel.thereAreFilesLoaded(),
                child: FloatingActionButton(
                  onPressed: () async {
                    setState(() {
                      Loading.show();
                    });
                    try {
                      final file = await viewModel.generatePreviewPdfDocument();
                      setState(() {
                        Utils.openFileProperly(context, file);
                      });
                    } catch (error) {
                      if (!context.mounted) return; // check "mounted" property
                      CustomDialog.showError(
                        context: context,
                        error: error,
                        titleLocalized: 'generate_file_error_title',
                        subtitleLocalized: 'generate_file_error_subtitle',
                        buttonTextLocalized: 'accept',
                      );
                    } finally {
                      setState(() {
                        Loading.hide();
                      });
                    }
                  },
                  backgroundColor: ColorsApp.kMainColor,
                  child: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
    );
  }
}
