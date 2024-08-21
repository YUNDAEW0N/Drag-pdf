import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drag_pdf/common/colors/colors_app.dart';
import 'package:drag_pdf/common/localization/localization.dart';
import 'package:drag_pdf/components/components.dart';
import 'package:drag_pdf/model/enums/loader_of.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
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

  Future<void> loadFilesOrImages(LoaderOf from, String barcode) async {
    setState(() {
      Loading.show();
    });
    try {
      switch (from) {
        case LoaderOf.imagesFromGallery:
          await viewModel.loadImagesFromStorage(barcode);
        case LoaderOf.filesFromFileSystem:
          await viewModel.loadFilesFromStorage(barcode);
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

  Future<void> scanImages(String barcode) async {
    try {
      context.pop('Scan');
      final file = await viewModel.scanDocument(barcode);
      if (file != null) {
        setState(() {
          Utils.printInDebug("Document Scanned: $file");
        });
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
                    onPressed: () async {
                      String? barcode = await scanBarcode();

                      if (barcode != null && barcode.isNotEmpty) {
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text(Localization.of(context)
                                .string('choose_an_option')),
                            content: Text(Localization.of(context)
                                .string('content_home_screen_dialog')),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  context.pop();
                                  FileDialog.add(
                                    context: context,
                                    loadImageFromGallery: () async =>
                                        await loadFilesOrImages(
                                            LoaderOf.imagesFromGallery,
                                            barcode),
                                    loadFileFromFileSystem: () async =>
                                        await loadFilesOrImages(
                                            LoaderOf.filesFromFileSystem,
                                            barcode),
                                  );
                                },
                                child: Text(Localization.of(context)
                                    .string('가져오기')), // LOAD
                              ),
                              TextButton(
                                onPressed: () async =>
                                    await scanImages(barcode),
                                child: Text(Localization.of(context)
                                    .string('스캔')), // SCAN
                              ),
                              TextButton(
                                onPressed: () => context.pop('취소'),
                                child: Text(
                                  Localization.of(context)
                                      .string('취소'), // Cancel
                                  style: const TextStyle(
                                      color: ColorsApp.kMainColor),
                                ),
                              )
                            ],
                          ),
                        );
                      } else {
                        showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text("에러"),
                            content: Text("바코드 스캔 실패 했습니다"),
                            actions: [
                              TextButton(
                                onPressed: () => context.pop(),
                                child: Text("확인"),
                              )
                            ],
                          ),
                        );
                      }
                    },
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
                              print("파일 위치: ${file.getName()}");
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
                            title: Text(file.getName()), //
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

  Future<String?> scanBarcode() async {
    try {
      String barcode = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Cancel',
        true,
        ScanMode.DEFAULT, //디폴트는 스캔/바코드 둘다 가능
      );
      return barcode == '-1' ? null : barcode;
    } catch (e) {
      return null;
    }
  }
}
