import 'package:drag_pdf/common/colors/colors_app.dart';
import 'package:drag_pdf/common/localization/localization.dart';
import 'package:drag_pdf/helper/file_manager.dart';
import 'package:drag_pdf/helper/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'helper/helpers.dart';

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSecureInf();
  await loadFirebase();
  await prepareApp();

// FileManager 인스턴스 생성 및 폴더 파일 카운트 초기화
  FileHelper fileHelper = AppSession.singleton.fileHelper;
  FileManager fileManager = FileManager(fileHelper);
  fileManager.initializeFolderFileCounts();

  // 폴더 파일 카운트 초기화 후 로컬에 저장된 파일 로드
  await fileManager.loadSavedFiles();

  // 앱 전체에서 사용할 수 있도록 FileManager 인스턴스를 AppSession에 저장
  AppSession.singleton.mfl = fileManager;
}

Future loadSecureInf() async {
  try {
    await dotenv.load(fileName: ".env");
  } catch (error) {
    debugPrint(".env file is not loaded!!");
  }
}

Future loadFirebase() async {
  FirebaseHelper.shared.initializeApp();
}

Future prepareApp() async {
  await AppSession.singleton.fileHelper.loadLocalPath();
  //AppSession.singleton.fileHelper.emptyLocalDocumentFolder();
}

void main() async {
  await initializeApp();
  runApp(MyApp(fileManager: AppSession.singleton.mfl));
}

class MyApp extends StatelessWidget {
  final FileManager fileManager;

  const MyApp({super.key, required this.fileManager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      locale: const Locale('ko'),
      routerConfig: AppRouter.shared.getRouter(),
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData.light(useMaterial3: true).copyWith(
        primaryColor: ColorsApp.white,
        appBarTheme: const AppBarTheme(
            color: ColorsApp.kMainColor, foregroundColor: Colors.white),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          foregroundColor: Colors.white,
        ),
      ),
      localizationsDelegates: const [
        Localization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('es'),
      ],
    );
  }
}
