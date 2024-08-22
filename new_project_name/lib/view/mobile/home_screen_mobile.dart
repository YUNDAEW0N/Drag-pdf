import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drag_pdf/common/colors/colors_app.dart';
import 'package:drag_pdf/common/localization/localization.dart';
import 'package:drag_pdf/components/components.dart';
import 'package:drag_pdf/model/enums/loader_of.dart';

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

  // QR or Barcode 스캔 관련 변수 추가
  //----------------------------------------------------------------------
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  String scannedTitle = '';
  bool isBarcodeMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    qrController?.dispose();
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
          break;
        case LoaderOf.filesFromFileSystem:
          await viewModel.loadFilesFromStorage();
          break;
      }
    } catch (error) {
      final subtitle =
          error.toString().contains(HomeViewModel.extensionForbidden)
              ? "forbidden_file_error_subtitle"
              : "read_file_error_subtitle";
      if (!mounted) return;
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

  // 스캔 모드 선택 다이얼로그 ( 추후 UI 꾸며야 함)
  //----------------------------------------------------------------------
  Future<void> _showScanModeDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Scan Mode'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text('Scan QR Code'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showQRView(context, false); // QR 코드 모드로 스캔
                  },
                ),
                const Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: const Text('Scan Barcode'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showQRView(context, true); // 바코드 모드로 스캔
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // QR 코드 스캔을 처리하는 메서드 추가
  //----------------------------------------------------------------------------
  Future<void> _showQRView(BuildContext context, bool isBarcodeMode) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(isBarcodeMode ? 'SCAN BARCODE' : 'SCAN QR CODE'),
          ),
          body: Stack(
            children: [
              QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.red,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutWidth: isBarcodeMode ? 300.0 : 250.0,
                  cutOutHeight: isBarcodeMode ? 100.0 : 250.0,
                ),
              ),
              if (isBarcodeMode)
                // 바코드 모드용 가이드라인
                Center(
                  child: Container(
                    width: 300, // 바코드 스캔 가이드라인의 너비
                    height: 100, // 바코드 스캔 가이드라인의 높이
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              else
                // QR 코드 모드용 가이드라인
                Center(
                  child: Container(
                    width: 250, // QR 코드 스캔 가이드라인의 너비
                    height: 250, // QR 코드 스캔 가이드라인의 높이
                    child: Stack(
                      children: [
                        // 좌상단 모서리
                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white, width: 4),
                                left: BorderSide(color: Colors.white, width: 4),
                              ),
                            ),
                          ),
                        ),
                        // 우상단 모서리
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white, width: 4),
                                right:
                                    BorderSide(color: Colors.white, width: 4),
                              ),
                            ),
                          ),
                        ),
                        // 좌하단 모서리
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom:
                                    BorderSide(color: Colors.white, width: 4),
                                left: BorderSide(color: Colors.white, width: 4),
                              ),
                            ),
                          ),
                        ),
                        // 우하단 모서리
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom:
                                    BorderSide(color: Colors.white, width: 4),
                                right:
                                    BorderSide(color: Colors.white, width: 4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.qrController = controller;

    String? lastScannedCode;
    int scanCount = 0;
    const int requiredScans = 3; // 동일한 코드가 3번 인식되면 유효한 것으로 간주

    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null && scanData.code != lastScannedCode) {
        lastScannedCode = scanData.code;
        scanCount = 1;
      } else if (scanData.code == lastScannedCode) {
        scanCount++;
      }

      if (scanCount >= requiredScans) {
        setState(() {
          scannedTitle = scanData.code ?? "Unknown"; // QR 코드 스캔 결과 저장
        });

        controller.stopCamera(); // 스캔이 완료되면 카메라 멈춤

        // 스캔 후 문서 스캔 화면으로 이동
        Navigator.of(context).pop(); // 스캔 화면 닫기
        _navigateToDocumentScanner(context, scannedTitle);
      }
    });
  }

  Future<void> _navigateToDocumentScanner(
      BuildContext context, String title) async {
    // 문서 스캔 화면으로 전환
    final fileread = await viewModel.scanDocument(title); // QR 코드 정보 전달
    if (fileread != null) {
      setState(() {
        Utils.printInDebug("Document Scanned: ${fileread.getName()}");
      });
    }
  }

  Future<void> scanImages() async {
    try {
      // 이전 스캔 타이틀 초기화
      scannedTitle = '';

      // QR/바코드 스캔 방식을 먼저 선택
      await _showScanModeDialog();

      // 이후 스캔 결과를 사용하여 문서 스캔
      if (scannedTitle.isNotEmpty) {
        final fileread =
            await viewModel.scanDocument(scannedTitle); // QR 코드 정보 전달
        if (fileread != null) {
          setState(() {
            Utils.printInDebug("Document Scanned: ${fileread.getName()}");
          });
        }
      }
    } catch (error) {
      if (!mounted) return; // check "mounted" property
      CustomDialog.showError(
        context: context,
        error: error,
        titleLocalized: 'read_file_error_title',
        subtitleLocalized: 'scan_file_error_subtitle',
        buttonTextLocalized: 'accept',
      );
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
                    onPressed: () async =>
                        await scanImages(), // 다이얼로그 대신 scanImages 호출
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
