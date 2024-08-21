import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../model/models.dart';
import 'helpers.dart';

class IsolateHelper {
  static Future<FileRead> createRotateIsolate(FileRead file) async {
    /// Where I listen to the message from Mike's port
    ReceivePort myReceivePort = ReceivePort();

    /// Spawn an isolate, passing my receivePort sendPort
    Isolate.spawn<SendPort>(rotateImageWasPressed, myReceivePort.sendPort);

    /// Mike sends a senderPort for me to enable me to send him a message via his sendPort.
    /// I receive Mike's senderPort via my receivePort
    SendPort mikeSendPort = await myReceivePort.first;

    /// I set up another receivePort to receive Mike's response.
    ReceivePort mikeResponseReceivePort = ReceivePort();

    /// I send Mike a message using mikeSendPort. I send him a list,
    /// which includes my message, preferred type of coffee, and finally
    /// a sendPort from mikeResponseReceivePort that enables Mike to send a message back to me.
    mikeSendPort.send([file, mikeResponseReceivePort.sendPort]);

    /// I get Mike's response by listening to mikeResponseReceivePort
    return await mikeResponseReceivePort.first as FileRead;
  }

  static void rotateImageWasPressed(SendPort mySendPort) async {
    /// Set up a receiver port for Mike
    ReceivePort mikeReceivePort = ReceivePort();

    /// Send Mike receivePort sendPort via mySendPort
    mySendPort.send(mikeReceivePort.sendPort);

    /// Listen to messages sent to Mike's receive port
    await for (var message in mikeReceivePort) {
      if (message is List) {
        final file = message[0];
        AppSession.singleton.mfl.rotateImageInMemoryAndFile(file);

        /// Get Mike's response sendPort
        final SendPort mikeResponseSendPort = message[1];

        /// Send Mike's response via mikeResponseSendPort
        Isolate.exit(mikeResponseSendPort, file); // DONE
      }
    }
  }

  static Future<FileRead> createResizeIsolate(
      FileRead file, int width, int height) async {
    /// Where I listen to the message from Mike's port
    ReceivePort myReceivePort = ReceivePort();

    /// Spawn an isolate, passing my receivePort sendPort
    Isolate.spawn<SendPort>(resizeImageWasPressed, myReceivePort.sendPort);

    /// Mike sends a senderPort for me to enable me to send him a message via his sendPort.
    /// I receive Mike's senderPort via my receivePort
    SendPort mikeSendPort = await myReceivePort.first;

    /// I set up another receivePort to receive Mike's response.
    ReceivePort mikeResponseReceivePort = ReceivePort();

    /// I send Mike a message using mikeSendPort. I send him a list,
    /// which includes my message, preferred type of coffee, and finally
    /// a sendPort from mikeResponseReceivePort that enables Mike to send a message back to me.
    mikeSendPort.send([file, width, height, mikeResponseReceivePort.sendPort]);

    /// I get Mike's response by listening to mikeResponseReceivePort
    return await mikeResponseReceivePort.first as FileRead;
  }

  static void resizeImageWasPressed(SendPort mySendPort) async {
    /// Set up a receiver port for Mike
    ReceivePort mikeReceivePort = ReceivePort();

    /// Send Mike receivePort sendPort via mySendPort
    mySendPort.send(mikeReceivePort.sendPort);

    /// Listen to messages sent to Mike's receive port
    await for (var message in mikeReceivePort) {
      if (message is List) {
        final file = message[0];
        final width = message[1];
        final height = message[2];
        AppSession.singleton.mfl
            .resizeImageInMemoryAndFile(file, width, height);

        /// Get Mike's response sendPort
        final SendPort mikeResponseSendPort = message[3];

        /// Send Mike's response via mikeResponseSendPort
        Isolate.exit(mikeResponseSendPort, file);
      }
    }
  }

  static Future<List<FileRead>> createAddMultiplesImagesIsolate(
      List<XFile> files) async {
    /// Where I listen to the message from Mike's port
    ReceivePort myReceivePort = ReceivePort();

    /// Spawn an isolate, passing my receivePort sendPort
    Isolate.spawn<SendPort>(
        launchAddMultiplesImagesIsolate, myReceivePort.sendPort);

    /// Mike sends a senderPort for me to enable me to send him a message via his sendPort.
    /// I receive Mike's senderPort via my receivePort
    SendPort mikeSendPort = await myReceivePort.first;

    /// I set up another receivePort to receive Mike's response.
    ReceivePort mikeResponseReceivePort = ReceivePort();

    /// I send Mike a message using mikeSendPort. I send him a list,
    /// which includes my message, preferred type of coffee, and finally
    /// a sendPort from mikeResponseReceivePort that enables Mike to send a message back to me.
    mikeSendPort.send([
      files,
      AppSession.singleton.fileHelper.localPath,
      AppSession.singleton.mfl.nextNames(files.length),
      mikeResponseReceivePort.sendPort
    ]);

    /// I get Mike's response by listening to mikeResponseReceivePort
    return await mikeResponseReceivePort.first as List<FileRead>;
  }

  static void launchAddMultiplesImagesIsolate(SendPort mySendPort) async {
    /// Set up a receiver port for Mike
    ReceivePort mikeReceivePort = ReceivePort();

    /// Send Mike receivePort sendPort via mySendPort
    mySendPort.send(mikeReceivePort.sendPort);

    /// Listen to messages sent to Mike's receive port
    await for (var message in mikeReceivePort) {
      if (message is List) {
        final files = message[0];
        final localPath = message[1];
        final names = message[2];
        final filesSaved = await AppSession.singleton.mfl
            .addMultipleImagesOnDisk(files, localPath, names);

        /// Get Mike's response sendPort
        final SendPort mikeResponseSendPort = message[3];

        /// Send Mike's response via mikeResponseSendPort
        Isolate.exit(mikeResponseSendPort, filesSaved); // DONE
      }
    }
  }

  static FileRead createFileRead(File file) {
    String fileName = file.path.split('/').last;
    String extension = fileName.split('.').last;
    int size = file.lengthSync();

    img.Image? image = null;

    // FileRead 객체 생성
    return FileRead(file, fileName, image, size, extension);
  }

}
