import 'package:drag_pdf/helper/file_manager.dart';
import 'package:drag_pdf/view/mobile/document_screen_mobile.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drag_pdf/common/colors/colors_app.dart';
import 'package:drag_pdf/common/localization/localization.dart';
import 'package:drag_pdf/components/components.dart';
import 'package:drag_pdf/model/enums/loader_of.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

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
  final FileManager _mfl = AppSession.singleton.mfl;
  String? selectedFolderName;
  String? branchName;

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
    _loadBranchName();
    loadUploadStatus();
  }

  // SharedPreferences에서 지점명을 불러오는 메서드
  Future<void> _loadBranchName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      branchName = prefs.getString('branchName') ?? 'Drag PDF'; // 기본값 설정
    });
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

  Future<void> loadUploadStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> uploadedFolders = prefs.getStringList('uploadedFolders') ?? [];

    // 로컬에 존재하는 실제 폴더 목록을 가져옴
    List<String> existingFolders =
        await _mfl.loadFolderNames(); // 로컬 폴더 목록을 가져오는 메서드

    // 존재하지 않는 폴더를 업로드 상태 목록에서 제거
    List<String> validUploadedFolders = [];
    for (String folder in uploadedFolders) {
      if (existingFolders.contains(folder)) {
        validUploadedFolders.add(folder);
        _mfl.folderUploadStatus[folder] = true;
      } else {
        // 존재하지 않는 폴더는 업로드 상태에서 제거
        _mfl.folderUploadStatus[folder] = false;
      }
    }

    // SharedPreferences에 유효한 업로드된 폴더 목록을 다시 저장
    await prefs.setStringList('uploadedFolders', validUploadedFolders);

    // UI 업데이트
    setState(() {});
  }

  Future<void> loadFilesOrImages(LoaderOf from) async {
    setState(() {
      // Loading.show();
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
        // Loading.hide();
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
    Loading.show(context); // 로딩 화면 표시

    try {
      final fileRead =
          await viewModel.scanDocument(title, "SHB"); // scanDocument 실행
      if (fileRead != null) {
        // 폴더 목록 화면을 새로고침하거나 이동
        setState(() {
          viewModel.getFolderNames(); // 폴더 목록 갱신
        });
      }
    } finally {
      Loading.hide(); // 작업이 완료되면 로딩 화면 숨기기
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
            await viewModel.scanDocument(scannedTitle, "SHB"); // QR 코드 정보 전달
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
    final folderNames = viewModel.getFolderNames();

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Text('$branchName 문서 관리'),
          actions: [
            IconButton(
              onPressed: () async => await scanImages(),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: folderNames.isNotEmpty
            ? Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: folderNames.length,
                      itemBuilder: (context, index) {
                        final folderName = folderNames[index];
                        final isUploaded =
                            _mfl.folderUploadStatus[folderName] ??
                                false; // 업로드 상태 확인

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: 4.0,
                          color: isUploaded
                              ? Colors.green[100]
                              : Colors.white, // 업로드된 폴더는 녹색 배경
                          child: ListTile(
                            leading: Icon(
                              isUploaded
                                  ? Icons.check_circle
                                  : Icons.folder, // 업로드된 폴더는 체크 아이콘
                              color: isUploaded
                                  ? Colors.green
                                  : ColorsApp.kMainColor,
                              size: 40,
                            ),
                            title: Text(
                              folderName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isUploaded
                                    ? Colors.green
                                    : ColorsApp.kMainColor, // 업로드된 폴더는 녹색 텍스트
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: ColorsApp.kMainColor,
                              size: 20,
                            ),
                            onTap: () {
                              setState(() {
                                selectedFolderName = folderName; // 선택된 폴더 이름 저장
                              });
                              viewModel.openFolder(folderName, context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/files/file.png',
                      height: 100,
                      width: 100,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '저장된 폴더가 없습니다.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
