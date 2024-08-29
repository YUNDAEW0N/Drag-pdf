import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class FileUploader {
  final String baseUrl = 'http://118.217.19.215:8088/dniplus-link/shipboxes';

  Future<void> uploadFiles(String shipBoxNo, Map<String, String> boxInfo,
      Map<String, Map<String, String>> fileInfo, List<String> filePaths) async {
    try {
      var uri = Uri.parse('$baseUrl/$shipBoxNo');
      var request = http.MultipartRequest('POST', uri);

      // boxInfo와 fileInfo를 JSON으로 변환하여 shipBoxRequest에 포함
      Map<String, dynamic> shipBoxRequest = {
        'boxInfo': boxInfo,
        'fileInfo': fileInfo,
      };

      // shipBoxRequest 내용을 프린트
      print('shipBoxRequest 내용: ${jsonEncode(shipBoxRequest)}');

      // shipBoxRequest를 JSON 문자열로 변환하여 multipart로 추가
      request.files.add(http.MultipartFile.fromString(
        'shipBoxRequest',
        jsonEncode(shipBoxRequest),
        contentType: MediaType('application', 'json'),
      ));

      // 파일 추가
      for (var filePath in filePaths) {
        var file = File(filePath);
        var mimeType = lookupMimeType(file.path);
        request.files.add(await http.MultipartFile.fromPath(
          'files',
          file.path,
          contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
          filename: path.basename(file.path),
        ));
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        print('파일 업로드 성공');
        var responseData = await http.Response.fromStream(response);
        print('응답 데이터: ${utf8.decode(responseData.bodyBytes)}');
      } else {
        print('파일 업로드 실패: ${response.statusCode}');
        var responseData = await http.Response.fromStream(response);
        print('에러 응답 데이터: ${utf8.decode(responseData.bodyBytes)}');
      }
    } catch (e) {
      print('파일 업로드 중 오류 발생: $e');
    }
  }
}
