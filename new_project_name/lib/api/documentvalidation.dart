import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://118.217.19.215:8088';

  Future<Map<String, dynamic>> checkDocumentNumber(
      String docNo, String affCd) async {
    final String url =
        '$baseUrl/dniplus-link/shipboxes/docs/$docNo?affCd=$affCd';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json',
      });

      // HTTP 상태 코드 출력
      print('HTTP 상태 코드: ${response.statusCode}');

      // 응답 헤더 출력
      print('응답 헤더: ${response.headers}');

      // 응답 본문을 UTF-8로 디코딩하여 출력
      final responseBody = utf8.decode(response.bodyBytes);
      print('응답 본문: $responseBody');

      if (response.statusCode == 200) {
        // JSON 파싱 후 반환
        return jsonDecode(responseBody) as Map<String, dynamic>;
      } else {
        print('서버 오류: ${response.statusCode}');
        return {
          'resultCd': '99',
          'resultMsg': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('예외 발생: $e');
      return {'resultCd': '99', 'resultMsg': 'Exception occurred: $e'};
    }
  }
}
