import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class Loading {
  static final Loading _instance = Loading._internal();

  factory Loading() {
    return _instance;
  }

  Loading._internal();

  static bool isPresented = false;
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context) {
    if (!isPresented) {
      isPresented = true;
      _overlayEntry = _createOverlayEntry(context);
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  static void hide() {
    if (isPresented && _overlayEntry != null) {
      _overlayEntry!.remove();
      isPresented = false;
      _overlayEntry = null;
    }
  }

  static OverlayEntry _createOverlayEntry(BuildContext context) {
    return OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: Material(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Lottie.asset('assets/animations/loading.json'),
          ),
        ),
      ),
    );
  }
}
