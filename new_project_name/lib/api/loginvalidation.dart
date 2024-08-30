import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> checkBranchCode(String affCd, String brCd) async {
  final url = Uri.parse(
      'http://118.217.19.215:8088/dniplus-link/shipboxes/branches/$brCd?affCd=$affCd');

  // Request 로그 출력
  print('Request: GET $url');

  final response = await http.get(url);

  // Response 로그 출력
  print('Response status: ${response.statusCode}');
  final responseBody = utf8.decode(response.bodyBytes);
  print('Response body: $responseBody');

  if (response.statusCode == 200) {
    final data = jsonDecode(responseBody);
    final resultCd = data['resultCd'];
    if (resultCd == '01') {
      final branchName = data['brNm'];
      print('Branch name: $branchName');

      // SharedPreferences에 저장
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('branchName', branchName);

      return branchName; // 지점 이름 반환
    } else {
      print('Invalid branch code');
      return null; // 유효하지 않은 지점코드일 경우 null 반환
    }
  } else {
    print('Error: Failed to validate branch code');
    throw Exception('지점코드 확인 실패: 서버 오류');
  }
}
