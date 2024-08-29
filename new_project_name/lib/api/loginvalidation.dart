import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> checkBranchCode(String affCd, String brCd) async {
  final url = Uri.parse(
      'http://118.217.19.215:8088/dniplus-link/shipboxes/branches/$brCd?affCd=$affCd');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final resultCd = data['resultCd'];
    if (resultCd == '01') {
      return data['branchName']; // 지점 이름 반환
    } else {
      return null; // 유효하지 않은 지점코드일 경우 null 반환
    }
  } else {
    throw Exception('지점코드 확인 실패: 서버 오류');
  }
}