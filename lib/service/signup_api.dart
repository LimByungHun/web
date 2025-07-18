import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://10.101.170.63';

Future<Map<String, dynamic>> checkID(String userID) async {
  final url = Uri.parse('$baseUrl/user/check_id?id=$userID');

  final response = await http.get(url);

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    return {'available': false, 'message': '서버 오류: ${response.statusCode}'};
  }
}

Future<Map<String, dynamic>> registerUser({
  required String id,
  required String password,
  required String name,
}) async {
  final url = Uri.parse('$baseUrl/user/register');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'id': id, 'pw': password, 'name': name}),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    return {'success': false, 'message': '서버 오류: ${response.statusCode}'};
  }
}
