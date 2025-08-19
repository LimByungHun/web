import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://192.168.0.76';

class LogoutApi {
  static Future<bool> logout(String refreshToken) async {
    final url = Uri.parse('$baseUrl/user/logout');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      return false;
    }
  }
}
