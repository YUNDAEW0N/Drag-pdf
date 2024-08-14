import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:mobilescanner/ViewModel/pdf_view_model.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PdfViewModel()..loadInitialData(),
      child: MaterialApp(
        home: PdfScannerScreen(),
      ),
    );
  }
}

class PdfScannerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PdfViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("모바일 스캐너"),
        actions: [
          IconButton(
            onPressed: viewModel.getImageFromGallery,
            icon: const Icon(Icons.image),
          ),
          IconButton(
            onPressed: viewModel.getImageFromCamera,
            icon: const Icon(Icons.camera),
          ),
        ],
      ),
      body: viewModel.selectedImage == null
          ? PdfListView()
          : Stack(
              children: [
                Positioned.fill(
                  child: Image.file(viewModel.selectedImage!),
                ),
                if (viewModel.cropRect != null)
                  Positioned(
                    left: viewModel.cropRect!.left,
                    top: viewModel.cropRect!.top,
                    child: Container(
                      width: viewModel.cropRect!.width,
                      height: viewModel.cropRect!.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onPanStart: viewModel.onPanStart,
                  onPanUpdate: viewModel.onPanUpdate,
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: ElevatedButton(
                    onPressed: viewModel.savePdf,
                    child: const Text('Save PDF'),
                  ),
                ),
              ],
            ),
    );
  }
}

class PdfListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<PdfViewModel>(context);

    return ListView.builder(
      itemCount: viewModel.pdfFiles.length,
      itemBuilder: (context, index) {
        final pdfFile = viewModel.pdfFiles[index];
        return ListTile(
          title: Text(pdfFile.fileName),
          trailing: IconButton(
            icon: Icon(Icons.open_in_new),
            onPressed: () {
              OpenFile.open(pdfFile.file.path);
            },
          ),
        );
      },
    );
  }
}
